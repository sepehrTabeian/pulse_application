// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get appTitle => 'پالس';

  @override
  String get actionRetry => 'تلاش دوباره';

  @override
  String get actionAdd => 'افزودن';

  @override
  String get navWatchlist => 'کیف پول';

  @override
  String get homeTitle => 'کیف پول من';

  @override
  String get chaosSwitchTooltip =>
      'دمو: شبکهٔ طوفانی (قطعی، تأخیر و خطا) را روشن یا خاموش کنید';

  @override
  String get homeTabHoldings => 'دارایی‌های من';

  @override
  String get homeTabWatchlist => 'پیگیری';

  @override
  String get holdingsHint => 'این‌ها دارایی واقعی شماست.';

  @override
  String get watchlistHint =>
      'این نمادها را فقط دنبال می‌کنید؛ دارایی شما نیستند. برای حذف، ردیف را بکشید.';

  @override
  String get holdingsEmptyTitle => 'هنوز دارایی‌ای ندارید';

  @override
  String get holdingsEmptyBody =>
      'از تب «پیگیری» یک نماد را باز کنید و اولین خریدتان را ثبت کنید.';

  @override
  String get holdingsAssetEmpty => 'در این دسته دارایی‌ای ندارید.';

  @override
  String get holdingsEmptyAction => 'رفتن به پیگیری';

  @override
  String get balanceStatCash => 'نقد';

  @override
  String get balanceStatAssets => 'دارایی‌ها';

  @override
  String get balanceStatSellNow => 'فروش فوری';

  @override
  String get navOrders => 'سفارش‌ها';

  @override
  String get ordersTitle => 'سفارش‌ها';

  @override
  String get orderFilterAll => 'همه';

  @override
  String get orderFilterFilled => 'انجام‌شده';

  @override
  String get orderFilterPending => 'در حال بررسی';

  @override
  String get orderFilterWorking => 'در صف';

  @override
  String get orderFilterRejected => 'ردشده';

  @override
  String get orderFilterCancelled => 'لغوشده';

  @override
  String get orderStatusFilled => 'انجام‌شده';

  @override
  String get orderStatusPending => 'در حال بررسی';

  @override
  String get orderStatusWorking => 'در صف';

  @override
  String get orderStatusRejected => 'ردشده';

  @override
  String get orderStatusCancelled => 'لغوشده';

  @override
  String get orderStatusUnknown => 'نامشخص';

  @override
  String get ordersEmptyTitle => 'هنوز سفارشی ثبت نشده';

  @override
  String get ordersEmptyBody => 'بعد از ثبت اولین سفارش، اینجا دیده می‌شود.';

  @override
  String get ordersEmptyFilteredTitle => 'سفارشی در این دسته نیست';

  @override
  String get ordersEmptyFilteredBody =>
      'دسته دیگری را انتخاب کنید یا همه را ببینید.';

  @override
  String get ordersLoadFailedTitle => 'سفارش‌ها بارگذاری نشد';

  @override
  String orderSideType(String side, String type) {
    return '$side · $type';
  }

  @override
  String orderQuantityLine(String quantity, String unit) {
    return 'تعداد: $quantity $unit';
  }

  @override
  String get orderFilterStatusLabel => 'وضعیت';

  @override
  String get orderFilterAssetLabel => 'نوع دارایی';

  @override
  String get assetAll => 'همه دارایی‌ها';

  @override
  String get assetStock => 'سهام';

  @override
  String get assetCrypto => 'کریپتو';

  @override
  String get orderRejectedReasonUnknown => 'سرور سفارش را نپذیرفت.';

  @override
  String orderLimitPrice(String price) {
    return 'قیمت حدی: $price';
  }

  @override
  String orderFilledAt(String price) {
    return 'میانگین قیمت اجرا: $price';
  }

  @override
  String get navSearchAdd => 'جستجو و افزودن';

  @override
  String get unitShare => 'سهم';

  @override
  String get actionEdit => 'ویرایش';

  @override
  String get actionDone => 'تمام';

  @override
  String get actionRemove => 'حذف از فهرست';

  @override
  String get actionClose => 'بستن';

  @override
  String get actionDismiss => 'متوجه شدم';

  @override
  String get actionMoreInfo => 'اطلاعات بیشتر';

  @override
  String get actionCheckOrderStatus => 'بررسی وضعیت سفارش';

  @override
  String get actionBackToList => 'بازگشت به فهرست';

  @override
  String get loadingLabel => 'در حال بارگذاری';

  @override
  String get haltedBadge => 'متوقف';

  @override
  String get haltedPriceNote => 'قیمت پایانی قبلی';

  @override
  String get staleBadge => 'قدیمی';

  @override
  String get watchlistTitle => 'پیگیری قیمت‌ها';

  @override
  String get watchlistEmptyTitle => 'فهرست پیگیری خالی است';

  @override
  String get watchlistEmptyBody =>
      'برای شروع، از «جستجو و افزودن» در پایین صفحه نماد اضافه کنید.';

  @override
  String get watchlistLoadFailedTitle => 'فهرست بارگذاری نشد';

  @override
  String get watchlistSaveRolledBack =>
      'تغییرات ذخیره نشد و فهرست به آخرین حالت ذخیره‌شده برگشت.';

  @override
  String watchlistReorderHandle(String symbol) {
    return 'جابه‌جایی $symbol';
  }

  @override
  String get feedConnecting => 'در حال اتصال به قیمت‌های زنده...';

  @override
  String get feedStale => 'قیمت‌ها ممکن است قدیمی باشند.';

  @override
  String get feedOffline => 'اتصال قیمت‌ها قطع است؛ در حال تلاش دوباره.';

  @override
  String feedLastUpdate(String time) {
    return 'آخرین به‌روزرسانی: $time';
  }

  @override
  String get feedInfoTitle => 'وضعیت قیمت‌ها';

  @override
  String get feedInfoBody =>
      'قیمت‌ها از یک اتصال زنده می‌رسند. اگر چند ثانیه هیچ پیامی نرسد، قیمت‌ها «قدیمی» علامت می‌خورند و برنامه خودکار دوباره وصل می‌شود. سفارش‌ها همیشه با قیمت لحظه‌ای سرور اجرا می‌شوند و مبلغ‌های نمایش‌داده‌شده فقط تخمینی هستند.';

  @override
  String get directionUp => 'افزایش';

  @override
  String get directionDown => 'کاهش';

  @override
  String get directionFlat => 'بدون تغییر';

  @override
  String rowSemantics(
    String symbol,
    String price,
    String direction,
    String change,
  ) {
    return '$symbol، قیمت $price، $direction $change';
  }

  @override
  String get portfolioTitle => 'پرتفوی';

  @override
  String get portfolioCash => 'موجودی نقد';

  @override
  String get portfolioMarketValue => 'ارزش تقریبی دارایی‌ها';

  @override
  String get portfolioSellNow => 'ارزش فروش فوری';

  @override
  String get portfolioTotal => 'مجموع تقریبی';

  @override
  String get portfolioApproximate => 'برخی قیمت‌ها تقریبی هستند.';

  @override
  String get portfolioMissingPrice =>
      'برای برخی دارایی‌ها قیمتی در دسترس نیست.';

  @override
  String get portfolioLoadFailed => 'پرتفوی بارگذاری نشد.';

  @override
  String get portfolioInfoTitle => 'ارزش‌گذاری پرتفوی';

  @override
  String get portfolioInfoBody =>
      'ارزش تقریبی دارایی‌ها با آخرین قیمت معامله حساب می‌شود. ارزش فروش فوری با بهترین قیمت خریدار حساب می‌شود و اگر همین حالا بفروشید، مبلغ نزدیک به آن خواهد بود. برای نمادهای متوقف یا بدون قیمت زنده، قیمت پایانی قبلی استفاده می‌شود و عدد «تقریبی» است. موجودی نقد همیشه از سرور خوانده می‌شود.';

  @override
  String get searchTitle => 'جستجوی نماد';

  @override
  String get searchHint => 'نام یا نماد';

  @override
  String get searchPrompt => 'برای شروع، نام یا نماد را وارد کنید.';

  @override
  String get searchNoResults => 'نتیجه‌ای پیدا نشد.';

  @override
  String get searchAlreadyAdded => 'در فهرست است';

  @override
  String get ticketTitle => 'ثبت سفارش';

  @override
  String get sideBuy => 'خرید';

  @override
  String get sideSell => 'فروش';

  @override
  String get typeMarket => 'بازار';

  @override
  String get typeLimit => 'حدی';

  @override
  String get quantityLabel => 'تعداد';

  @override
  String get limitPriceLabel => 'قیمت حدی';

  @override
  String get estimatedAmount => 'مبلغ تخمینی';

  @override
  String get estimatedUnavailable => 'قیمتی برای تخمین در دسترس نیست.';

  @override
  String get costBasisAsk => 'بر اساس قیمت فروشنده';

  @override
  String get costBasisBid => 'بر اساس قیمت خریدار';

  @override
  String get costBasisLimit => 'بر اساس قیمت حدی';

  @override
  String get costBasisLast => 'بر اساس آخرین قیمت';

  @override
  String get estimateStaleNote => 'قیمت قدیمی است؛ مبلغ دقیق نیست.';

  @override
  String get submitOrder => 'ارسال سفارش';

  @override
  String get ticketOfflineBlocked =>
      'تا برقراری دوباره اتصال قیمت‌ها امکان ثبت سفارش نیست.';

  @override
  String get validationRequired => 'این فیلد الزامی است.';

  @override
  String get validationInvalidCharacters =>
      'فقط عدد وارد کنید و برای اعشار از نقطه استفاده کنید.';

  @override
  String get validationTooLong => 'عدد خیلی طولانی است.';

  @override
  String get validationTooPrecise => 'تعداد ارقام اعشار زیاد است.';

  @override
  String get validationNotPositive => 'عدد باید بزرگ‌تر از صفر باشد.';

  @override
  String validationNotMultipleOfLot(String step) {
    return 'تعداد باید مضرب $step باشد.';
  }

  @override
  String validationNotMultipleOfTick(String step) {
    return 'قیمت باید مضرب $step باشد.';
  }

  @override
  String get orderSending => 'در حال ارسال سفارش...';

  @override
  String get orderChecking => 'در حال بررسی سفارش‌های قبلی...';

  @override
  String get orderResolving =>
      'پاسخی نرسید؛ وضعیت سفارش در حال بررسی است. لطفاً صبر کنید و سفارش را دوباره ارسال نکنید.';

  @override
  String orderResolvingAttempt(String attempt) {
    return 'تلاش شماره $attempt';
  }

  @override
  String get orderUnresolvedTitle => 'وضعیت سفارش هنوز مشخص نیست';

  @override
  String get orderUnresolvedBody =>
      'ممکن است سفارش اجرا شده باشد. تا مشخص شدن وضعیت، سفارش جدیدی برای این نماد ثبت نکنید.';

  @override
  String get orderFilledTitle => 'سفارش اجرا شد';

  @override
  String holdingLabel(String quantity, String unit) {
    return 'موجودی شما: $quantity $unit';
  }

  @override
  String get holdingNone => 'موجودی شما: ندارید';

  @override
  String availableToBuy(String amount) {
    return 'قابل خرید: $amount';
  }

  @override
  String availableToBuyMax(String quantity, String unit) {
    return 'حداکثر تعداد: $quantity $unit';
  }

  @override
  String availableToSell(String quantity, String unit) {
    return 'قابل فروش: $quantity $unit';
  }

  @override
  String get availableToSellNone => 'چیزی برای فروش ندارید.';

  @override
  String get actionMax => 'حداکثر';

  @override
  String get holdingsTitle => 'دارایی‌های شما';

  @override
  String get holdingsEmpty => 'هنوز دارایی‌ای ندارید.';

  @override
  String holdingValue(String value) {
    return 'حدود $value';
  }

  @override
  String get watchlistAssetEmpty => 'در این دسته نمادی ندارید.';

  @override
  String orderFilledBody(
    String quantity,
    String unit,
    String symbol,
    String price,
  ) {
    return '$quantity $unit از $symbol با میانگین قیمت $price اجرا شد.';
  }

  @override
  String get orderWorkingTitle => 'سفارش در صف است';

  @override
  String get orderWorkingBody => 'سفارش ثبت شد و هنوز اجرا نشده است.';

  @override
  String get orderRejectedTitle => 'سفارش ثبت نشد';

  @override
  String recoveryFilled(String symbol) {
    return 'سفارش قبلی $symbol اجرا شده بود.';
  }

  @override
  String recoveryWorking(String symbol) {
    return 'سفارش قبلی $symbol در صف است.';
  }

  @override
  String recoveryNotExecuted(String symbol) {
    return 'سفارش قبلی $symbol اجرا نشده بود.';
  }

  @override
  String recoveryStillUnresolved(String symbol) {
    return 'وضعیت سفارش قبلی $symbol هنوز نامشخص است.';
  }

  @override
  String get errorServiceUnavailable =>
      'سرویس موقتاً در دسترس نیست. دوباره تلاش می‌کنیم.';

  @override
  String get errorTimeout => 'پاسخی دریافت نشد. وضعیت در حال بررسی است.';

  @override
  String get errorInsufficientFunds => 'موجودی کافی نیست.';

  @override
  String get errorInsufficientPosition => 'مقدار دارایی برای فروش کافی نیست.';

  @override
  String get errorTradingHalted => 'معامله این نماد متوقف است.';

  @override
  String errorWatchlistFull(String max) {
    return 'فهرست پیگیری پر است (حداکثر $max نماد).';
  }

  @override
  String get errorUnknownSymbol => 'نماد پیدا نشد.';

  @override
  String get errorNotFound => 'مورد درخواستی پیدا نشد.';

  @override
  String get errorInvalidQuantity => 'مقدار واردشده معتبر نیست.';

  @override
  String get errorInvalidPrice => 'قیمت واردشده معتبر نیست.';

  @override
  String get errorInvalidRequest => 'درخواست نامعتبر است.';

  @override
  String get errorIdempotencyConflict =>
      'این سفارش با اطلاعات دیگری قبلاً ثبت شده است.';

  @override
  String get errorConnectionLost => 'اتصال قطع شد. در حال اتصال دوباره...';

  @override
  String get errorParsing => 'داده دریافتی قابل پردازش نیست.';

  @override
  String get errorStorage =>
      'ذخیره‌سازی روی دستگاه ناموفق بود؛ سفارش ارسال نشد.';

  @override
  String get errorValidation => 'اطلاعات واردشده معتبر نیست.';

  @override
  String get errorDuplicateSymbol => 'این نماد قبلاً در فهرست است.';

  @override
  String get errorUnknownServer => 'خطای ناشناخته از سرور.';

  @override
  String get errorUnexpected => 'خطای غیرمنتظره رخ داد.';

  @override
  String get chartTitle => 'نمودار قیمت';

  @override
  String get rangeDay => 'روز';

  @override
  String get rangeWeek => 'هفته';

  @override
  String get rangeMonth => 'ماه';

  @override
  String get chartEmpty => 'داده‌ای برای نمودار وجود ندارد.';

  @override
  String get chartLegend => 'شمع توخالی = صعودی، شمع توپر = نزولی';

  @override
  String chartSummary(String symbol, String count, String low, String high) {
    return 'نمودار شمعی $symbol: $count شمع، پایین‌ترین $low، بالاترین $high';
  }

  @override
  String chartSelected(
    String time,
    String open,
    String high,
    String low,
    String close,
  ) {
    return '$time · باز $open · بالا $high · پایین $low · بسته $close';
  }

  @override
  String get selectInstrumentTitle => 'یک نماد را انتخاب کنید';

  @override
  String get selectInstrumentBody =>
      'برای دیدن نمودار و ثبت سفارش، نماد را از فهرست انتخاب کنید.';

  @override
  String get switchBlocked =>
      'تا مشخص شدن وضعیت سفارش جاری، نماد دیگری را انتخاب نکنید.';
}
