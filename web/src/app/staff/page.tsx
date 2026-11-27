'use client';

import React, { useState, useEffect, useCallback } from 'react';

type Tab = 'orders' | 'menu' | 'notifications';
type DeviceType = 'personal' | 'shared_tablet';

interface OrderItem {
  id: string;
  name: string;
  quantity: number;
  price: number;
}

interface Order {
  id: string;
  order_number: string;
  restaurant_name: string;
  status: 'pending' | 'preparing' | 'ready_for_pickup' | 'delivered' | 'cancelled';
  total_price: number;
  created_at: string;
  items: OrderItem[];
  customer_name?: string;
  customer_phone?: string;
}

interface MenuItem {
  id: string;
  name: string;
  price: number;
  preparation_time: number;
  is_available: boolean;
  has_complex_variants: boolean;
}

interface CurrentUser {
  id: string;
  username: string;
  name: string;
  role: string;
  phone?: string;
}

export default function StaffPortalPage() {
  const [isAuthenticated, setIsAuthenticated] = useState<boolean>(false);
  const [currentUser, setCurrentUser] = useState<CurrentUser | null>(null);
  const [activeTab, setActiveTab] = useState<Tab>('orders');
  const [deviceType, setDeviceType] = useState<DeviceType>('personal');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [loginError, setLoginError] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  // Orders state
  const [orders, setOrders] = useState<Order[]>([]);
  const [orderFilter, setOrderFilter] = useState<'all' | 'pending' | 'preparing' | 'ready_for_pickup'>('pending');
  const [selectedOrderForCancel, setSelectedOrderForCancel] = useState<Order | null>(null);
  const [cancelReason, setCancelReason] = useState('');
  const [pollStatus, setPollStatus] = useState<'idle' | 'polling' | 'error'>('idle');

  // Menu items state
  const [menuItems, setMenuItems] = useState<MenuItem[]>([
    { id: '1', name: 'بيتزا مارغريتا (Pizza Margherita)', price: 650, preparation_time: 15, is_available: true, has_complex_variants: false },
    { id: '2', name: 'طاكوس دجاج مقرمش (Crispy Chicken Tacos)', price: 500, preparation_time: 12, is_available: true, has_complex_variants: true },
    { id: '3', name: 'برغر كلاسيك (Classic Burger)', price: 450, preparation_time: 10, is_available: true, has_complex_variants: false },
    { id: '4', name: 'علبة توفير كليوباترا (Special Box LTO)', price: 1200, preparation_time: 25, is_available: false, has_complex_variants: true },
  ]);

  // Push notifications state
  const [pushSupported, setPushSupported] = useState<boolean>(false);
  const [pushSubscribed, setPushSubscribed] = useState<boolean>(false);
  const [pushStatusMessage, setPushStatusMessage] = useState<string>('');

  // Register staff Service Worker
  useEffect(() => {
    if (typeof window !== 'undefined' && 'serviceWorker' in navigator) {
      navigator.serviceWorker
        .register('/staff-sw.js', { scope: '/staff/' })
        .then(() => {
          setPushSupported('PushManager' in window);
        })
        .catch((err) => console.error('[staff] SW registration error:', err));
    }
  }, []);

  // Check existing session on mount
  useEffect(() => {
    fetch('/staff/api/auth/session')
      .then((res) => (res.ok ? res.json() : null))
      .then((data) => {
        if (data?.authenticated && data.user) {
          setIsAuthenticated(true);
          setCurrentUser(data.user);
        }
      })
      .catch(() => {});
  }, []);

  // 15-second Poller while visible
  const fetchOrders = useCallback(async () => {
    if (!isAuthenticated) return;
    setPollStatus('polling');
    try {
      // Poller endpoint mock/fallback for Release 1
      setTimeout(() => {
        setPollStatus('idle');
      }, 500);
    } catch {
      setPollStatus('error');
    }
  }, [isAuthenticated]);

  useEffect(() => {
    if (!isAuthenticated) return;
    const interval = setInterval(fetchOrders, 15000);
    const handleFocus = () => fetchOrders();
    window.addEventListener('focus', handleFocus);

    return () => {
      clearInterval(interval);
      window.removeEventListener('focus', handleFocus);
    };
  }, [isAuthenticated, fetchOrders]);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoginError('');
    setIsSubmitting(true);

    if (!username.trim() || !password.trim()) {
      setLoginError('يرجى إدخال اسم المستخدم وكلمة المرور');
      setIsSubmitting(false);
      return;
    }

    try {
      const res = await fetch('/staff/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          username: username.trim(),
          password: password.trim(),
          device_type: deviceType,
        }),
      });

      const data = await res.json();
      if (res.ok && data.success) {
        setIsAuthenticated(true);
        setCurrentUser(data.user);
        // Populate active demo orders
        setOrders([
          {
            id: 'ord-101',
            order_number: 'SHL-9842',
            restaurant_name: 'Cleopatra Food',
            status: 'pending',
            total_price: 1850,
            created_at: new Date(Date.now() - 3 * 60 * 1000).toISOString(),
            customer_name: 'أحمد بن علي',
            customer_phone: '0555123456',
            items: [
              { id: 'i1', name: 'بيتزا مارغريتا', quantity: 2, price: 650 },
              { id: 'i2', name: 'كوكا كولا 1L', quantity: 1, price: 150 },
              { id: 'i3', name: 'بطاطا مقلية', quantity: 1, price: 400 },
            ],
          },
          {
            id: 'ord-102',
            order_number: 'SHL-9843',
            restaurant_name: 'Cleopatra Food',
            status: 'preparing',
            total_price: 950,
            created_at: new Date(Date.now() - 8 * 60 * 1000).toISOString(),
            customer_name: 'كريم م.',
            items: [{ id: 'i4', name: 'طاكوس دجاج XL', quantity: 1, price: 950 }],
          },
        ]);
      } else {
        setLoginError(data.error || 'فشل تسجيل الدخول. تحقق من البيانات المدخلة.');
      }
    } catch {
      setLoginError('تعذر الاتصال بالخادم. يرجى المحاولة لاحقاً.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleLogout = async () => {
    try {
      await fetch('/staff/api/auth/session', { method: 'DELETE' });
    } catch {
      // ignore
    }
    setIsAuthenticated(false);
    setCurrentUser(null);
  };

  const handleOrderStatusChange = (orderId: string, newStatus: Order['status'], reason?: string) => {
    setOrders((prev) =>
      prev.map((ord) => {
        if (ord.id === orderId) {
          return { ...ord, status: newStatus };
        }
        return ord;
      }),
    );
    if (newStatus === 'cancelled') {
      setSelectedOrderForCancel(null);
      setCancelReason('');
    }
  };

  const handleMenuAvailabilityToggle = (id: string) => {
    setMenuItems((prev) =>
      prev.map((item) => (item.id === id ? { ...item, is_available: !item.is_available } : item)),
    );
  };

  const handlePriceUpdate = (id: string, newPriceStr: string) => {
    const item = menuItems.find((m) => m.id === id);
    if (!item) return;

    if (item.has_complex_variants) {
      alert(
        '⚠️ تنبيه أمان: هذا الطبق يحتوي على أحجام أو إضافات متعددة (Variants). تعديل السعر المباشر محجوب لحماية تناسق القائمة. يرجى استخدام لوحة تحكم الأصناف الكاملة.',
      );
      return;
    }

    const price = Number(newPriceStr);
    if (isNaN(price) || price < 0) return;

    setMenuItems((prev) =>
      prev.map((m) => (m.id === id ? { ...m, price } : m)),
    );
  };

  const subscribePush = async () => {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      setPushStatusMessage('المتصفح لا يدعم الإشعارات الفورية');
      return;
    }
    try {
      const reg = await navigator.serviceWorker.ready;
      const sub = await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: 'BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkrxZJjSgSnfckjBJuBkr3qBUYIHBQFLXYp5Nksh8U',
      });
      setPushSubscribed(true);
      setPushStatusMessage('تم تفعيل التنبيهات الفورية بنجاح');
    } catch (err: any) {
      setPushStatusMessage('تم رفض الإذن أو تعذر الاشتراك: ' + err.message);
    }
  };

  return (
    <div className="flex flex-col min-h-screen max-w-4xl mx-auto w-full px-4 py-4 pb-16" dir="rtl">
      {/* Top Header */}
      <header className="flex items-center justify-between border-b border-slate-800 pb-4 mb-4">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-orange-600 to-amber-500 flex items-center justify-center text-white font-bold text-xl shadow-lg shadow-orange-950">
            س
          </div>
          <div>
            <h1 className="text-xl font-bold text-white flex items-center gap-2">
              بوابة ساهلة لإدارة المطعم
              <span className="text-xs bg-orange-900/60 text-orange-400 px-2 py-0.5 rounded-full border border-orange-700/50">
                Staff PWA
              </span>
            </h1>
            <p className="text-xs text-slate-400">إدارة الطلبات، التنبيهات المباشرة، وحالة قائمة الطعام</p>
          </div>
        </div>

        {isAuthenticated && (
          <div className="flex items-center gap-3">
            <div className="text-left hidden sm:block">
              <span className="block text-xs font-bold text-white">{currentUser?.name || 'طاقم العمل'}</span>
              <span className="text-[10px] bg-slate-800 text-slate-300 px-1.5 py-0.5 rounded border border-slate-700">
                {currentUser?.role === 'admin' ? 'مدير النظام (Admin)' : currentUser?.role || 'Staff'}
              </span>
            </div>
            <span
              className={`inline-block w-2.5 h-2.5 rounded-full ${
                pollStatus === 'polling'
                  ? 'bg-amber-400 animate-ping'
                  : pollStatus === 'error'
                  ? 'bg-rose-500'
                  : 'bg-emerald-400'
              }`}
              title={pollStatus === 'polling' ? 'جاري التحديث...' : 'متصل'}
            />
            <button
              onClick={handleLogout}
              className="text-xs bg-slate-900 hover:bg-slate-800 text-slate-300 border border-slate-700 px-3 py-1.5 rounded-lg transition min-h-[36px]"
            >
              خروج
            </button>
          </div>
        )}
      </header>

      {/* Login Screen */}
      {!isAuthenticated ? (
        <div className="flex flex-col items-center justify-center flex-1 py-8">
          <div className="w-full max-w-md bg-slate-900/80 border border-slate-800 rounded-2xl p-6 shadow-2xl backdrop-blur">
            <h2 className="text-lg font-bold text-white mb-2 text-center">تسجيل دخول طاقم العمل</h2>
            <p className="text-xs text-slate-400 mb-6 text-center">
              سجل دخولك باسم المستخدم الخاص بمطعمك (بدون بريد خارجي)
            </p>

            {loginError && (
              <div className="mb-4 p-3 rounded-xl bg-rose-950/60 border border-rose-800/80 text-rose-300 text-xs">
                {loginError}
              </div>
            )}

            <form onSubmit={handleLogin} className="space-y-4">
              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">اسم المستخدم (Username)</label>
                <input
                  type="text"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  placeholder="مثال: chef_amine أو manager_biskra"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-orange-500 transition"
                  dir="ltr"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-300 mb-1.5">كلمة المرور (Password)</label>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••"
                  className="w-full bg-slate-950 border border-slate-800 rounded-xl px-4 py-2.5 text-sm text-white focus:outline-none focus:border-orange-500 transition"
                  dir="ltr"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-300 mb-2">نوع الجهاز (جلسة العمل)</label>
                <div className="grid grid-cols-2 gap-2">
                  <button
                    type="button"
                    onClick={() => setDeviceType('personal')}
                    className={`p-3 rounded-xl border text-xs font-medium flex flex-col items-center gap-1 transition ${
                      deviceType === 'personal'
                        ? 'border-orange-500 bg-orange-950/30 text-orange-300'
                        : 'border-slate-800 bg-slate-950 text-slate-400'
                    }`}
                  >
                    <span>هاتف شخصي</span>
                    <span className="text-[10px] text-slate-500">مهلة خمول: 12 ساعة</span>
                  </button>

                  <button
                    type="button"
                    onClick={() => setDeviceType('shared_tablet')}
                    className={`p-3 rounded-xl border text-xs font-medium flex flex-col items-center gap-1 transition ${
                      deviceType === 'shared_tablet'
                        ? 'border-orange-500 bg-orange-950/30 text-orange-300'
                        : 'border-slate-800 bg-slate-950 text-slate-400'
                    }`}
                  >
                    <span>تابلت المطبخ المشترك</span>
                    <span className="text-[10px] text-slate-500">مهلة خمول: 30 دقيقة</span>
                  </button>
                </div>
              </div>

              <button
                type="submit"
                disabled={isSubmitting}
                className="w-full py-3 bg-gradient-to-r from-orange-600 to-amber-600 hover:from-orange-500 hover:to-amber-500 text-white font-bold rounded-xl text-sm shadow-lg shadow-orange-950 transition disabled:opacity-50 min-h-[44px]"
              >
                {isSubmitting ? 'جاري التحقق...' : 'دخول إلى البوابة'}
              </button>
            </form>
          </div>
        </div>
      ) : (
        /* Authenticated Staff Dashboard */
        <div className="flex flex-col flex-1 gap-4">
          {/* Main Tab Navigation */}
          <div className="flex border-b border-slate-800">
            <button
              onClick={() => setActiveTab('orders')}
              className={`flex-1 py-3 text-sm font-semibold border-b-2 transition ${
                activeTab === 'orders'
                  ? 'border-orange-500 text-orange-400 bg-orange-950/10'
                  : 'border-transparent text-slate-400 hover:text-slate-200'
              }`}
            >
              الطلبات المباشرة ({orders.filter((o) => o.status !== 'cancelled' && o.status !== 'delivered').length})
            </button>
            <button
              onClick={() => setActiveTab('menu')}
              className={`flex-1 py-3 text-sm font-semibold border-b-2 transition ${
                activeTab === 'menu'
                  ? 'border-orange-500 text-orange-400 bg-orange-950/10'
                  : 'border-transparent text-slate-400 hover:text-slate-200'
              }`}
            >
              قائمة الطعام والأسعار
            </button>
            <button
              onClick={() => setActiveTab('notifications')}
              className={`flex-1 py-3 text-sm font-semibold border-b-2 transition ${
                activeTab === 'notifications'
                  ? 'border-orange-500 text-orange-400 bg-orange-950/10'
                  : 'border-transparent text-slate-400 hover:text-slate-200'
              }`}
            >
              التنبيهات الفورية (Push)
            </button>
          </div>

          {/* Orders View */}
          {activeTab === 'orders' && (
            <div className="flex flex-col gap-4">
              {/* Order status filters */}
              <div className="flex gap-2 overflow-x-auto pb-1 text-xs">
                {(['pending', 'preparing', 'ready_for_pickup', 'all'] as const).map((filter) => (
                  <button
                    key={filter}
                    onClick={() => setOrderFilter(filter)}
                    className={`px-3 py-1.5 rounded-full border transition whitespace-nowrap min-h-[36px] ${
                      orderFilter === filter
                        ? 'bg-orange-500 border-orange-500 text-white font-bold'
                        : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-slate-200'
                    }`}
                  >
                    {filter === 'pending'
                      ? 'قيد الانتظار'
                      : filter === 'preparing'
                      ? 'قيد التحضير'
                      : filter === 'ready_for_pickup'
                      ? 'جاهز للاستلام'
                      : 'الكل'}
                  </button>
                ))}
              </div>

              {/* Order Cards List */}
              <div className="flex flex-col gap-3">
                {orders
                  .filter((o) => (orderFilter === 'all' ? true : o.status === orderFilter))
                  .map((order) => (
                    <div
                      key={order.id}
                      className="bg-slate-900 border border-slate-800 rounded-2xl p-4 flex flex-col gap-3 shadow-md"
                    >
                      <div className="flex items-center justify-between border-b border-slate-800/80 pb-2">
                        <div>
                          <span className="text-base font-bold text-white tracking-wide">{order.order_number}</span>
                          <span className="text-xs text-slate-400 mr-2">{order.customer_name}</span>
                        </div>
                        <span
                          className={`text-xs px-2.5 py-1 rounded-full font-bold ${
                            order.status === 'pending'
                              ? 'bg-rose-950/80 text-rose-300 border border-rose-800/50 animate-pulse'
                              : order.status === 'preparing'
                              ? 'bg-amber-950/80 text-amber-300 border border-amber-800/50'
                              : order.status === 'ready_for_pickup'
                              ? 'bg-emerald-950/80 text-emerald-300 border border-emerald-800/50'
                              : 'bg-slate-800 text-slate-400'
                          }`}
                        >
                          {order.status === 'pending'
                            ? 'بانتظار الموافقة'
                            : order.status === 'preparing'
                            ? 'جاري التحضير'
                            : order.status === 'ready_for_pickup'
                            ? 'جاهز للاستلام'
                            : order.status}
                        </span>
                      </div>

                      {/* Items */}
                      <div className="space-y-1">
                        {order.items.map((item) => (
                          <div key={item.id} className="flex justify-between text-xs text-slate-300">
                            <span>
                              {item.quantity}x {item.name}
                            </span>
                            <span className="text-slate-400">{item.price * item.quantity} دج</span>
                          </div>
                        ))}
                      </div>

                      {/* Total & Action Buttons */}
                      <div className="flex items-center justify-between pt-2 border-t border-slate-800/80">
                        <div>
                          <span className="text-xs text-slate-400">المجموع: </span>
                          <span className="text-sm font-bold text-orange-400">{order.total_price} دج</span>
                        </div>

                        <div className="flex gap-2">
                          {order.status === 'pending' && (
                            <>
                              <button
                                onClick={() => handleOrderStatusChange(order.id, 'preparing')}
                                className="px-4 py-2 bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl text-xs font-bold transition min-h-[44px]"
                              >
                                قبول الطلب
                              </button>
                              <button
                                onClick={() => setSelectedOrderForCancel(order)}
                                className="px-3 py-2 bg-rose-900/40 hover:bg-rose-900 text-rose-300 border border-rose-800/60 rounded-xl text-xs font-medium transition min-h-[44px]"
                              >
                                رفض
                              </button>
                            </>
                          )}

                          {order.status === 'preparing' && (
                            <button
                              onClick={() => handleOrderStatusChange(order.id, 'ready_for_pickup')}
                              className="px-4 py-2 bg-amber-600 hover:bg-amber-500 text-white rounded-xl text-xs font-bold transition min-h-[44px]"
                            >
                              جاهز للتوصيل
                            </button>
                          )}
                        </div>
                      </div>
                    </div>
                  ))}

                {orders.filter((o) => (orderFilter === 'all' ? true : o.status === orderFilter)).length === 0 && (
                  <div className="py-12 text-center text-slate-500 text-xs">
                    لا توجد طلبات في هذه الحالة حالياً
                  </div>
                )}
              </div>
            </div>
          )}

          {/* Menu Management View */}
          {activeTab === 'menu' && (
            <div className="flex flex-col gap-4">
              <div className="bg-slate-900/60 border border-slate-800 rounded-2xl p-4 text-xs text-slate-400 leading-relaxed">
                ℹ️ <strong className="text-slate-200">الإصدار 1 (Release 1):</strong> يمكنك تفعيل/تعطيل توفر الأطباق،
                تعديل وقت التحضير، وتحديث السعر الأساسي للأطباق البسيطة. الأطباق التي تحتوي على مقاسات متعددة أو عروض LTO
                محمية من تعديل السعر المباشر لمنع فقدان البيانات.
              </div>

              <div className="flex flex-col gap-3">
                {menuItems.map((item) => (
                  <div
                    key={item.id}
                    className="bg-slate-900 border border-slate-800 rounded-2xl p-4 flex flex-col md:flex-row md:items-center justify-between gap-4"
                  >
                    <div className="flex items-center gap-3">
                      <button
                        onClick={() => handleMenuAvailabilityToggle(item.id)}
                        className={`w-12 h-6 rounded-full transition relative flex items-center p-0.5 ${
                          item.is_available ? 'bg-emerald-600' : 'bg-slate-700'
                        }`}
                        title={item.is_available ? 'متوفر' : 'غير متوفر'}
                      >
                        <div
                          className={`w-5 h-5 rounded-full bg-white transition transform ${
                            item.is_available ? '-translate-x-6' : 'translate-x-0'
                          }`}
                        />
                      </button>
                      <div>
                        <h4 className="text-sm font-bold text-white flex items-center gap-2">
                          {item.name}
                          {item.has_complex_variants && (
                            <span className="text-[10px] bg-slate-800 text-slate-400 px-1.5 py-0.5 rounded border border-slate-700">
                              أحجام متعددة
                            </span>
                          )}
                        </h4>
                        <span className="text-xs text-slate-400">وقت التحضير: {item.preparation_time} دقيقة</span>
                      </div>
                    </div>

                    <div className="flex items-center gap-3">
                      <div className="flex items-center gap-1.5">
                        <span className="text-xs text-slate-400">السعر:</span>
                        <input
                          type="number"
                          defaultValue={item.price}
                          disabled={item.has_complex_variants}
                          onBlur={(e) => handlePriceUpdate(item.id, e.target.value)}
                          className={`w-24 bg-slate-950 border rounded-lg px-2 py-1 text-sm text-center font-bold text-white focus:outline-none ${
                            item.has_complex_variants
                              ? 'border-slate-800 text-slate-500 cursor-not-allowed opacity-60'
                              : 'border-slate-700 focus:border-orange-500'
                          }`}
                          dir="ltr"
                        />
                        <span className="text-xs text-slate-400">دج</span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Web Push Alerts View */}
          {activeTab === 'notifications' && (
            <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 flex flex-col gap-4">
              <h3 className="text-base font-bold text-white">إعداد التنبيهات الفورية (Web Push)</h3>
              <p className="text-xs text-slate-400 leading-relaxed">
                قم بتفعيل الإشعارات الفورية على هذا الجهاز لتلقي رنين مميز فور وصول طلب جديد لمطعمك، حتى وإن كان المتصفح في
                الخلفية.
              </p>

              {pushStatusMessage && (
                <div className="p-3 bg-slate-950 border border-slate-800 rounded-xl text-xs text-slate-300">
                  {pushStatusMessage}
                </div>
              )}

              <button
                onClick={subscribePush}
                disabled={pushSubscribed}
                className="py-3 px-6 bg-orange-600 hover:bg-orange-500 text-white font-bold rounded-xl text-xs shadow-lg transition disabled:opacity-50 min-h-[44px] self-start"
              >
                {pushSubscribed ? 'التنبيهات مفعلة على هذا الجهاز ✓' : 'تفعيل إشعارات الطلبات الفورية'}
              </button>
            </div>
          )}
        </div>
      )}

      {/* Cancellation Reason Modal */}
      {selectedOrderForCancel && (
        <div className="fixed inset-0 bg-black/80 flex items-center justify-center p-4 z-50">
          <div className="bg-slate-900 border border-slate-800 rounded-2xl p-6 max-w-md w-full shadow-2xl flex flex-col gap-4">
            <h3 className="text-base font-bold text-white">إلغاء الطلب {selectedOrderForCancel.order_number}</h3>
            <p className="text-xs text-slate-400">
              يرجى تحديد سبب الإلغاء ليتم إرساله للزبون وتوثيق العملية في سجل النظام:
            </p>

            <textarea
              value={cancelReason}
              onChange={(e) => setCancelReason(e.target.value)}
              placeholder="مثال: نفاد المكونات الأساسية، المطعم مغلق للصيانة..."
              rows={3}
              className="w-full bg-slate-950 border border-slate-800 rounded-xl p-3 text-xs text-white focus:outline-none focus:border-rose-500"
            />

            <div className="flex gap-2 justify-end">
              <button
                onClick={() => setSelectedOrderForCancel(null)}
                className="px-4 py-2 bg-slate-800 text-slate-300 rounded-xl text-xs font-medium"
              >
                تراجع
              </button>
              <button
                onClick={() => handleOrderStatusChange(selectedOrderForCancel.id, 'cancelled', cancelReason)}
                disabled={!cancelReason.trim() || cancelReason.trim().length < 3}
                className="px-4 py-2 bg-rose-600 hover:bg-rose-500 text-white rounded-xl text-xs font-bold transition disabled:opacity-40"
              >
                تأكيد الإلغاء
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
