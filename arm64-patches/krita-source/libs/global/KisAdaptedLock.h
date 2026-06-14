/*
 *  SPDX-FileCopyrightText: 2023 Dmitry Kazakov <dimula73@gmail.com>
 *
 *  SPDX-License-Identifier: GPL-2.0-or-later
 */

#ifndef KISADAPTEDLOCK_H
#define KISADAPTEDLOCK_H

#include <mutex>
#include <type_traits>

namespace kis_adapted_lock_detail {

template <typename Adapter, typename = void>
struct has_try_lock : std::false_type {};

template <typename Adapter>
struct has_try_lock<Adapter,
        std::void_t<decltype(std::declval<Adapter&>().try_lock())>>
    : std::true_type {};

/**
 * MSVC eagerly instantiates std::unique_lock::try_lock() even when it is
 * never called, which requires the adapter to provide try_lock(). The
 * adapter interface documents try_lock() as optional, so wrap the adapter
 * in a shim that supplies a blocking try_lock() fallback when the adapter
 * does not define its own. On compilers that lazily instantiate members
 * this is a no-op in practice.
 */
template <typename Adapter>
struct AdapterShim : Adapter
{
    using Adapter::Adapter;
    AdapterShim(const Adapter &a) : Adapter(a) {}

    template <typename A = Adapter>
    std::enable_if_t<has_try_lock<A>::value, bool> try_lock()
    {
        return Adapter::try_lock();
    }

    template <typename A = Adapter>
    std::enable_if_t<!has_try_lock<A>::value, bool> try_lock()
    {
        Adapter::lock();
        return true;
    }
};

} // namespace kis_adapted_lock_detail

/**
 * A wrapper class that adapts std::unique_lock to any kind
 * of locking that might be necessary to a particular class.
 *
 * Just define an Adapter class that implements `lock()`,
 * `unlock()` and (optionally) `try_lock()` interface and
 * pass it to `KisAdaptedLock`. The resulting class will
 * behave as normal `std::unique_lock` and lock/unlock the
 * object as you instructed it.
 *
 * See examples in `KisCursorOverrideLockAdapter` and
 * `KisLockFrameGenerationLock`
 */
template <typename Adapter>
class KisAdaptedLock
    : protected kis_adapted_lock_detail::AdapterShim<Adapter>,
      public std::unique_lock<kis_adapted_lock_detail::AdapterShim<Adapter>>
{
    using Shim = kis_adapted_lock_detail::AdapterShim<Adapter>;
public:
    template<typename Object>
    KisAdaptedLock(Object object)
        : Shim(object)
        , std::unique_lock<Shim>(
              static_cast<Shim&>(*this))
    {}

    template<typename Object>
    KisAdaptedLock(Object object, std::try_to_lock_t t)
        : Shim(object)
        , std::unique_lock<Shim>(static_cast<Shim&>(*this), t)
    {}

    template<typename Object>
    KisAdaptedLock(Object object, std::defer_lock_t t)
        : Shim(object)
        , std::unique_lock<Shim>(static_cast<Shim&>(*this), t)
    {}

    template<typename Object>
    KisAdaptedLock(Object object, std::adopt_lock_t t)
        : Shim(object)
        , std::unique_lock<Shim>(static_cast<Shim&>(*this), t)
    {}

    KisAdaptedLock(KisAdaptedLock &&rhs)
        : Shim(static_cast<Shim&>(rhs))
        , std::unique_lock<Shim>(
              static_cast<Shim&>(*this), std::adopt_lock)
    {
        rhs.release();
    }

    KisAdaptedLock& operator=(KisAdaptedLock &&rhs)
    {
        static_cast<std::unique_lock<Shim>&>(*this) =
            std::unique_lock<Shim>(static_cast<Shim&>(*this),
                                      std::adopt_lock);
        static_cast<Shim&>(*this) = rhs;
        rhs.release();
        return *this;
    }

    using std::unique_lock<Shim>::try_lock;
    using std::unique_lock<Shim>::lock;
    using std::unique_lock<Shim>::unlock;
    using std::unique_lock<Shim>::owns_lock;
};

/**
 * A macro to make sure that the resulting lock is
 * a 'class' and can be forward-declared instead of
 * the entire include pulling
 */
#define KIS_DECLARE_ADAPTED_LOCK(Name, Adapter) \
class Name : public KisAdaptedLock<Adapter>     \
{                                               \
    public:                                     \
    using BaseClass = KisAdaptedLock<Adapter>;  \
    using BaseClass::BaseClass;                 \
};

#endif // KISADAPTEDLOCK_H
