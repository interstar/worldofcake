#pragma once

#include "ControlRunnerBase.h"

#include <hxcpp.h>

#include <cstddef>

namespace worldofcake
{
    namespace bridge
    {
        /**
            Owning pointer to a Haxe object held in C++ heap memory, registered as
            an hxcpp GC root while it is set. The collector only scans attached
            thread stacks, so an object referenced solely from a C++ member is
            otherwise free to be collected while the runner still uses it.
            Assign and clear it on the attached control thread.
        */
        template <typename T>
        class RootedObjectPtr
        {
          public:
            RootedObjectPtr() = default;
            RootedObjectPtr(const RootedObjectPtr&) = delete;
            RootedObjectPtr& operator=(const RootedObjectPtr&) = delete;
            ~RootedObjectPtr()
            {
                *this = nullptr;
            }

            RootedObjectPtr& operator=(const ::hx::ObjectPtr<T>& object)
            {
                if (ptr.mPtr != nullptr)
                    hx::GCRemoveRoot(root());
                ptr = object;
                if (ptr.mPtr != nullptr)
                    hx::GCAddRoot(root());
                return *this;
            }
            RootedObjectPtr& operator=(std::nullptr_t)
            {
                return *this = ::hx::ObjectPtr<T>();
            }

            T* operator->() const
            {
                return ptr.mPtr;
            }
            T* get() const
            {
                return ptr.mPtr;
            }

          private:
            hx::Object** root()
            {
                return reinterpret_cast<hx::Object**>(&ptr.mPtr);
            }

            ::hx::ObjectPtr<T> ptr;
        };

        /**
            Runner layer that owns one Haxe harness (a `SequencerHarness` subclass)
            and applies the lifecycle commands every sequencer understands. Concrete
            runners handle only their app-specific commands in `applyAppCommand`.
        */
        template <typename HarnessObj>
        class HarnessControlRunner : public ControlRunnerBase
        {
          protected:
            RootedObjectPtr<HarnessObj> harness;

            virtual void applyAppCommand(const ControlCommand& command) = 0;

            /** Runner-side bookkeeping after a model reset, e.g. a runner-owned clock. */
            virtual void onModelReset()
            {
            }

          private:
            void applyCommand(const ControlCommand& command) final
            {
                switch (command.kind) {
                case CommandKind::setPaused:
                    harness->setPaused(command.value > 0.5);
                    break;
                case CommandKind::setMuted:
                    harness->setMuted(command.value > 0.5);
                    break;
                case CommandKind::reset:
                    harness->reset();
                    onModelReset();
                    break;
                default:
                    applyAppCommand(command);
                    break;
                }
            }

            void onCommandsApplied() final
            {
                if (harness.get() != nullptr)
                    publishModelLifecycle(harness->paused(), harness->muted());
            }

            /** Copy the model's published control outputs (decided in Haxe) for hosts to read. */
            void onTickComplete() final
            {
                if (harness.get() == nullptr)
                    return;
                const int count = harness->controlOutputCount();
                for (int i = 0; i < count && i < kMaxControlOutputs; ++i)
                    publishControlOutput(i, static_cast<float>(harness->controlOutputValue(i)));
                publishControlOutputCount(count);
            }
        };
    } // namespace bridge
} // namespace worldofcake
