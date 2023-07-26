#include "DataFlowActivityAnalysis.h"
#include "Dialect/Ops.h"
#include "Interfaces/AutoDiffTypeInterface.h"

#include "mlir/Analysis/DataFlow/ConstantPropagationAnalysis.h"
#include "mlir/Analysis/DataFlow/DeadCodeAnalysis.h"
#include "mlir/Analysis/DataFlow/DenseAnalysis.h"
#include "mlir/Analysis/DataFlow/SparseAnalysis.h"
#include "mlir/Analysis/DataFlowFramework.h"
#include "mlir/Interfaces/SideEffectInterfaces.h"

// TODO: Don't depend on specific dialects
#include "mlir/Dialect/LLVMIR/LLVMDialect.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"

#include "mlir/Analysis/AliasAnalysis/LocalAliasAnalysis.h"

using namespace mlir;
using namespace mlir::dataflow;

/// From Enzyme proper's activity analysis, there are four activity states.
// constant instruction vs constant value, a value/instruction (one and the same
// in LLVM) can be a constant instruction but active value, active instruction
// but constant value, or active/constant both.

// In MLIR, values are not the same as instructions. Many operations produce
// zero or one result, but there are operations that can produce multiple.

// The result of activity states are potentially different for multiple
// enzyme.autodiff calls.

// We could use enyzme::Activity here but I don't know that it would help from a
// dataflow perspective (distinguishing between enzyme_dup, enzyme_dupnoneed,
// enzyme_out, which are all active)
enum class ActivityKind { Active, Constant };

using llvm::errs;
class ValueActivity {
public:
  static ValueActivity getConstant() {
    return ValueActivity(ActivityKind::Constant);
  }

  static ValueActivity getActive() {
    return ValueActivity(ActivityKind::Active);
  }

  bool isActive() const {
    return value.has_value() && *value == ActivityKind::Active;
  }

  bool isConstant() const {
    return value.has_value() && *value == ActivityKind::Constant;
  }

  ValueActivity(std::optional<ActivityKind> value = std::nullopt)
      : value(std::move(value)) {}

  /// Whether the activity state is uninitialized. This happens when the state
  /// hasn't been set during the analysis.
  bool isUninitialized() const { return !value.has_value(); }

  /// Get the known activity state.
  const ActivityKind &getValue() const {
    assert(!isUninitialized());
    return *value;
  }

  bool operator==(const ValueActivity &rhs) const { return value == rhs.value; }

  static ValueActivity join(const ValueActivity &lhs,
                            const ValueActivity &rhs) {
    if (lhs.isUninitialized())
      return rhs;
    if (rhs.isUninitialized())
      return lhs;
    if (lhs.isConstant() && rhs.isConstant()) {
      return ValueActivity::getConstant();
    }

    return ValueActivity::getActive();
  }

  void print(raw_ostream &os) const {
    if (!value) {
      os << "<uninitialized>";
      return;
    }
    switch (*value) {
    case ActivityKind::Active:
      os << "Active";
      break;
    case ActivityKind::Constant:
      os << "Constant";
      break;
    }
  }

  raw_ostream &operator<<(raw_ostream &os) const {
    print(os);
    return os;
  }

private:
  /// The known activity kind.
  std::optional<ActivityKind> value;
};

class ForwardValueActivity : public Lattice<ValueActivity> {
public:
  using Lattice::Lattice;
};

class BackwardValueActivity : public Lattice<ValueActivity> {
public:
  using Lattice::Lattice;
};

/// This needs to keep track of three things:
///   1. Could active info store in?
///   2. Could active info load out?
///   3. Could constant info propagate (store?) in?
///
/// Active: active in && active out && !const in
/// ActiveOrConstant: active in && active out && const in
/// Constant: everything else
struct MemoryActivityState {
  bool activeLoad;
  bool activeStore;
  // Active init is like active store, but a special case for arguments. We need
  // to distinguish arguments that start with active data vs arguments that get
  // active data stored into them during the function.
  bool activeInit;

  bool operator==(const MemoryActivityState &other) {
    return activeLoad == other.activeLoad && activeStore == other.activeStore &&
           activeInit == other.activeInit;
  }

  bool operator!=(const MemoryActivityState &other) {
    return !(*this == other);
  }
};

// TODO: the internal representation of an alias class is an unsigned. In the
// long run, this should be switched with one or more distinct attributes.
using AliasClass = unsigned;
// TODO: This should not be global, but it needs to be shared by the various
// MemoryActivity lattices.
static DenseMap<Value, AliasClass> aliasClasses;

class MemoryActivity : public AbstractDenseLattice {
public:
  using AbstractDenseLattice::AbstractDenseLattice;

  /// Clear all modifications.
  ChangeResult reset() {
    if (activityStates.empty())
      return ChangeResult::NoChange;
    activityStates.clear();
    return ChangeResult::Change;
  }

  /// Join the activity states.
  ChangeResult join(const AbstractDenseLattice &lattice) override {
    const auto &rhs = static_cast<const MemoryActivity &>(lattice);
    ChangeResult result = ChangeResult::NoChange;
    for (const auto &state : rhs.activityStates) {
      auto &lhsState = activityStates[state.first];
      if (lhsState != state.second) {
        lhsState.activeLoad |= state.second.activeLoad;
        lhsState.activeStore |= state.second.activeStore;
        lhsState.activeInit |= state.second.activeInit;
        result |= ChangeResult::Change;
      }
    }
    return result;
  }

  bool hasActiveData(Value value) const {
    auto state = activityStates.lookup(aliasClasses[value]);
    return state.activeStore || state.activeInit;
  }

  bool hasActiveStore(Value value) const {
    return activityStates.lookup(aliasClasses[value]).activeStore;
  }

  /// Set the internal activity state.
  ChangeResult setActiveStore(Value value, bool activeStore) {
    auto &state = activityStates[aliasClasses.lookup(value)];
    ChangeResult result = ChangeResult::NoChange;
    if (state.activeStore != activeStore) {
      result = ChangeResult::Change;
      state.activeStore = activeStore;
    }
    return result;
  }

  ChangeResult setActiveLoad(Value value, bool activeLoad) {
    auto &state = activityStates[aliasClasses.lookup(value)];
    ChangeResult result = ChangeResult::NoChange;
    if (state.activeLoad != activeLoad) {
      result = ChangeResult::Change;
      state.activeLoad = activeLoad;
    }
    return result;
  }

  ChangeResult setActiveInit(Value value, bool activeInit) {
    auto &state = activityStates[aliasClasses.lookup(value)];
    ChangeResult result = ChangeResult::NoChange;
    if (state.activeInit != activeInit) {
      result = ChangeResult::Change;
      state.activeInit = activeInit;
    }
    return result;
  }

  void print(raw_ostream &os) const override {
    if (activityStates.empty()) {
      os << "<memory activity state was empty>"
         << "\n";
    }
    for (const auto &state : activityStates) {
      os << state.first << ": active load " << state.second.activeLoad
         << " active store " << state.second.activeStore << " active init "
         << state.second.activeInit << "\n";
    }
  }

  raw_ostream &operator<<(raw_ostream &os) const {
    print(os);
    return os;
  }

private:
  DenseMap<AliasClass, MemoryActivityState> activityStates;
};

/// Sparse activity analysis reasons about activity by traversing forward down
/// the def-use chains starting from active function arguments.
class SparseForwardActivityAnalysis
    : public SparseDataFlowAnalysis<ForwardValueActivity> {
public:
  using SparseDataFlowAnalysis::SparseDataFlowAnalysis;

  /// In general, we don't know anything about entry operands.
  /// TODO: If we're going forward though, we should always have initialized
  /// them.
  void setToEntryState(ForwardValueActivity *lattice) override {
    propagateIfChanged(lattice, lattice->join(ValueActivity()));
  }

  void visitOperation(Operation *op,
                      ArrayRef<const ForwardValueActivity *> operands,
                      ArrayRef<ForwardValueActivity *> results) override {
    if (op->hasTrait<OpTrait::ConstantLike>()) {
      for (auto result : results) {
        result->join(ValueActivity::getConstant());
      }
      return;
    }

    // For value-based AA, assume any active argument leads to an active result.
    // TODO: Could prune values based on the types of the operands (but would
    // require type analysis for full robustness)
    // TODO: Could we differentiate between values that don't propagate active
    // information? memcpy, stores don't produce active results (they don't
    // produce any). There are undoubtedly also function calls that don't
    // produce active results.
    ValueActivity joinedResult;
    for (auto operand : operands) {
      joinedResult = ValueActivity::join(joinedResult, operand->getValue());
    }

    for (auto result : results) {
      propagateIfChanged(result, result->join(joinedResult));
    }
  }
};

class SparseBackwardActivityAnalysis
    : public SparseBackwardDataFlowAnalysis<BackwardValueActivity> {
public:
  using SparseBackwardDataFlowAnalysis::SparseBackwardDataFlowAnalysis;

  void setToExitState(BackwardValueActivity *lattice) override {}

  void visitBranchOperand(OpOperand &operand) override {
    errs() << "Visiting branch operand: " << operand.get() << "\n";
  }

  void
  visitOperation(Operation *op, ArrayRef<BackwardValueActivity *> operands,
                 ArrayRef<const BackwardValueActivity *> results) override {
    ValueActivity joinedResult;
    for (auto result : results) {
      joinedResult = ValueActivity::join(joinedResult, result->getValue());
    }

    for (auto operand : operands) {
      propagateIfChanged(operand, operand->join(joinedResult));
    }
  }
};

class DenseForwardActivityAnalysis
    : public DenseDataFlowAnalysis<MemoryActivity> {
public:
  // DenseForwardActivityAnalysis()
  using DenseDataFlowAnalysis::DenseDataFlowAnalysis;

  void visitOperation(Operation *op, const MemoryActivity &before,
                      MemoryActivity *after) override {
    auto memory = dyn_cast<MemoryEffectOpInterface>(op);
    // If we can't reason about the memory effects, then conservatively assume
    // we can't deduce anything about activity via side-effects.
    if (!memory)
      return setToEntryState(after);

    SmallVector<MemoryEffects::EffectInstance> effects;
    memory.getEffects(effects);

    ChangeResult result = after->join(before);
    for (const auto &effect : effects) {
      Value value = effect.getValue();

      // If we see an effect on anything other than a value, assume we can't
      // deduce anything about the activity.
      if (!value)
        return setToEntryState(after);

      // TODO: From the upstream test dense analysis, we may need to copy paste
      // "Underlying Value" analysis to traverse call graphs correctly.

      // value =
      // getMostUnderlyingValue(value, [&](Value value) {
      //   return getOrCreateFor<UnderlyingValueLattice>(op, value);
      // });
      // if (!value)
      //   return;

      // In forward-flow, a value is active if loaded from a memory resource
      // that has previously been actively stored to.
      if (isa<MemoryEffects::Read>(effect.getEffect())) {
        // TODO: Look into using the MemorySlot interface to make this more
        // dialect agnostic
        if (auto loadOp = dyn_cast<LLVM::LoadOp>(op)) {
          if (before.hasActiveData(value)) {
            result |= after->setActiveLoad(value, true);

            // Mark the result as (forward) active
            auto *valueState =
                getOrCreate<ForwardValueActivity>(loadOp.getResult());
            result |= valueState->join(ValueActivity::getActive());
          }
        } else if (auto loadOp = dyn_cast<memref::LoadOp>(op)) {
          if (before.hasActiveData(value)) {
            result |= after->setActiveLoad(value, true);

            auto *valueState =
                getOrCreate<ForwardValueActivity>(loadOp.getResult());
            result |= valueState->join(ValueActivity::getActive());
          }
        }
      }

      if (isa<MemoryEffects::Write>(effect.getEffect())) {
        if (auto storeOp = dyn_cast<LLVM::StoreOp>(op)) {
          // If the activity for the stored value is updated, this should be
          // re-evaluated.
          auto *valueState =
              getOrCreateFor<ForwardValueActivity>(op, storeOp.getValue());
          if (valueState->getValue().isActive()) {
            result |= after->setActiveStore(value, true);
          }
        }
      }
    }
    propagateIfChanged(after, result);
  }

  // Not sure what this should be, unknown?
  void setToEntryState(MemoryActivity *lattice) override {
    propagateIfChanged(lattice, lattice->reset());
  }
};

/// Dense activity analysis requires a mapping from values to distinct alias
/// classes that are proven to not alias.
void basicAliasAnalysis(FunctionOpInterface callee,
                        DenseMap<Value, AliasClass> &aliasClasses,
                        bool annotate = false) {
  LocalAliasAnalysis localAliasAnalysis;
  aliasClasses.clear();
  callee.walk([&](Operation *op) {
    for (Value result : op->getResults()) {
      bool found = false;
      AliasClass toInsert;
      for (const auto &[key, aliasClass] : aliasClasses) {
        if (!localAliasAnalysis.alias(key, result).isNo()) {
          toInsert = aliasClass;
          found = true;
          break;
        }
      }
      if (!found) {
        toInsert = aliasClasses.size();
      }
      aliasClasses.insert({result, toInsert});

      if (annotate) {
        op->setAttr("ac",
                    IntegerAttr::get(IntegerType::get(callee.getContext(), 64),
                                     aliasClasses.lookup(result)));
      }
    }
  });
}

void enzyme::runDataFlowActivityAnalysis(
    FunctionOpInterface callee, ArrayRef<enzyme::Activity> argumentActivity,
    bool print) {
  SymbolTableCollection symbolTable;
  DataFlowSolver solver;
  basicAliasAnalysis(callee, aliasClasses, /*annotate=*/true);

  solver.load<SparseForwardActivityAnalysis>();
  // solver.load<SparseBackwardActivityAnalysis>(symbolTable);
  solver.load<DenseForwardActivityAnalysis>();

  // Required for the dataflow framework to traverse region-based control flow
  solver.load<DeadCodeAnalysis>();
  solver.load<SparseConstantPropagation>();

  // Initialize the argument states based on the given activity annotations.
  for (const auto &[arg, activity] :
       llvm::zip(callee.getArguments(), argumentActivity)) {
    // Need to determine if this is a pointer (or memref) or not, the dup
    // activity is kind of a proxy
    if (activity == enzyme::Activity::enzyme_dup ||
        activity == enzyme::Activity::enzyme_dupnoneed) {
      auto initialState = solver.getOrCreateState<MemoryActivity>(
          &callee.getFunctionBody().front());
      initialState->setActiveInit(arg, true);
    } else {
      auto *argLattice = solver.getOrCreateState<ForwardValueActivity>(arg);
      auto state = activity == enzyme::Activity::enzyme_const
                       ? ValueActivity::getConstant()
                       : ValueActivity::getActive();
      argLattice->join(state);
    }
  }

  // TODO: Double-check the way we detect return-like ops. For now, all direct
  // children of the FunctionOpInterface that have the ReturnLike trait are
  // considered returns of that function. Other terminators (various
  // scf/affine/linalg yield) also have the ReturnLike trait, but nested regions
  // shouldn't be traversed.
  for (Operation &op : callee.getFunctionBody().getOps()) {
    if (op.hasTrait<OpTrait::ReturnLike>()) {
      for (Value operand : op.getOperands()) {
        auto *returnLattice =
            solver.getOrCreateState<BackwardValueActivity>(operand);
        // Very basic type inference of the type
        returnLattice->join(
            isa<FloatType, MemRefType, LLVM::LLVMPointerType>(operand.getType())
                ? ValueActivity::getActive()
                : ValueActivity::getConstant());
      }
    }
  }

  if (failed(solver.initializeAndRun(callee))) {
    assert(false && "dataflow analysis failed\n");
  }

  if (print) {
    callee.walk([&](Operation *op) {
      for (OpResult result : op->getResults()) {
        auto forwardValueActivity =
            solver.lookupState<ForwardValueActivity>(result);
        if (forwardValueActivity) {
          std::string dest;
          llvm::raw_string_ostream sstream(dest);
          forwardValueActivity->getValue().print(sstream);
          op->setAttr("fvactive" + std::to_string(result.getResultNumber()),
                      StringAttr::get(op->getContext(), dest));
        }
      }
    });
  }

  // for (BlockArgument arg : callee.getArguments()) {
  //   auto argState = solver.lookupState<BackwardValueActivity>(arg);
  //   if (argState) {
  //     errs() << "function arg state: ";
  //     argState->getValue().print(errs());
  //     errs() << "\n";
  //   } else {
  //     errs() << "function argument backward state was null\n";
  //   }
  // }
  auto returnOp = callee.getFunctionBody().front().getTerminator();
  auto state = solver.lookupState<MemoryActivity>(returnOp);
  if (state) {
    errs() << "resulting state:\n" << *state << "\n";
  } else {
    errs() << "state was null\n";
  }
}