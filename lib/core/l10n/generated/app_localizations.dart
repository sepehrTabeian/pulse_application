import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_fa.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('fa')];

  /// No description provided for @appTitle.
  ///
  /// In fa, this message translates to:
  /// **'پالس'**
  String get appTitle;

  /// No description provided for @actionRetry.
  ///
  /// In fa, this message translates to:
  /// **'تلاش دوباره'**
  String get actionRetry;

  /// No description provided for @actionAdd.
  ///
  /// In fa, this message translates to:
  /// **'افزودن'**
  String get actionAdd;

  /// No description provided for @navWatchlist.
  ///
  /// In fa, this message translates to:
  /// **'کیف پول'**
  String get navWatchlist;

  /// No description provided for @homeTitle.
  ///
  /// In fa, this message translates to:
  /// **'کیف پول من'**
  String get homeTitle;

  /// No description provided for @chaosSwitchTooltip.
  ///
  /// In fa, this message translates to:
  /// **'دمو: شبکهٔ طوفانی (قطعی، تأخیر و خطا) را روشن یا خاموش کنید'**
  String get chaosSwitchTooltip;

  /// No description provided for @homeTabHoldings.
  ///
  /// In fa, this message translates to:
  /// **'دارایی‌های من'**
  String get homeTabHoldings;

  /// No description provided for @homeTabWatchlist.
  ///
  /// In fa, this message translates to:
  /// **'پیگیری'**
  String get homeTabWatchlist;

  /// No description provided for @holdingsHint.
  ///
  /// In fa, this message translates to:
  /// **'این‌ها دارایی واقعی شماست.'**
  String get holdingsHint;

  /// No description provided for @watchlistHint.
  ///
  /// In fa, this message translates to:
  /// **'این نمادها را فقط دنبال می‌کنید؛ دارایی شما نیستند. برای حذف، ردیف را بکشید.'**
  String get watchlistHint;

  /// No description provided for @holdingsEmptyTitle.
  ///
  /// In fa, this message translates to:
  /// **'هنوز دارایی‌ای ندارید'**
  String get holdingsEmptyTitle;

  /// No description provided for @holdingsEmptyBody.
  ///
  /// In fa, this message translates to:
  /// **'از تب «پیگیری» یک نماد را باز کنید و اولین خریدتان را ثبت کنید.'**
  String get holdingsEmptyBody;

  /// No description provided for @holdingsAssetEmpty.
  ///
  /// In fa, this message translates to:
  /// **'در این دسته دارایی‌ای ندارید.'**
  String get holdingsAssetEmpty;

  /// No description provided for @holdingsEmptyAction.
  ///
  /// In fa, this message translates to:
  /// **'رفتن به پیگیری'**
  String get holdingsEmptyAction;

  /// No description provided for @balanceStatCash.
  ///
  /// In fa, this message translates to:
  /// **'نقد'**
  String get balanceStatCash;

  /// No description provided for @balanceStatAssets.
  ///
  /// In fa, this message translates to:
  /// **'دارایی‌ها'**
  String get balanceStatAssets;

  /// No description provided for @balanceStatSellNow.
  ///
  /// In fa, this message translates to:
  /// **'فروش فوری'**
  String get balanceStatSellNow;

  /// No description provided for @navOrders.
  ///
  /// In fa, this message translates to:
  /// **'سفارش‌ها'**
  String get navOrders;

  /// No description provided for @ordersTitle.
  ///
  /// In fa, this message translates to:
  /// **'سفارش‌ها'**
  String get ordersTitle;

  /// No description provided for @orderFilterAll.
  ///
  /// In fa, this message translates to:
  /// **'همه'**
  String get orderFilterAll;

  /// No description provided for @orderFilterFilled.
  ///
  /// In fa, this message translates to:
  /// **'انجام‌شده'**
  String get orderFilterFilled;

  /// No description provided for @orderFilterPending.
  ///
  /// In fa, this message translates to:
  /// **'در حال بررسی'**
  String get orderFilterPending;

  /// No description provided for @orderFilterWorking.
  ///
  /// In fa, this message translates to:
  /// **'در صف'**
  String get orderFilterWorking;

  /// No description provided for @orderFilterRejected.
  ///
  /// In fa, this message translates to:
  /// **'ردشده'**
  String get orderFilterRejected;

  /// No description provided for @orderFilterCancelled.
  ///
  /// In fa, this message translates to:
  /// **'لغوشده'**
  String get orderFilterCancelled;

  /// No description provided for @orderStatusFilled.
  ///
  /// In fa, this message translates to:
  /// **'انجام‌شده'**
  String get orderStatusFilled;

  /// No description provided for @orderStatusPending.
  ///
  /// In fa, this message translates to:
  /// **'در حال بررسی'**
  String get orderStatusPending;

  /// No description provided for @orderStatusWorking.
  ///
  /// In fa, this message translates to:
  /// **'در صف'**
  String get orderStatusWorking;

  /// No description provided for @orderStatusRejected.
  ///
  /// In fa, this message translates to:
  /// **'ردشده'**
  String get orderStatusRejected;

  /// No description provided for @orderStatusCancelled.
  ///
  /// In fa, this message translates to:
  /// **'لغوشده'**
  String get orderStatusCancelled;

  /// No description provided for @orderStatusUnknown.
  ///
  /// In fa, this message translates to:
  /// **'نامشخص'**
  String get orderStatusUnknown;

  /// No description provided for @ordersEmptyTitle.
  ///
  /// In fa, this message translates to:
  /// **'هنوز سفارشی ثبت نشده'**
  String get ordersEmptyTitle;

  /// No description provided for @ordersEmptyBody.
  ///
  /// In fa, this message translates to:
  /// **'بعد از ثبت اولین سفارش، اینجا دیده می‌شود.'**
  String get ordersEmptyBody;

  /// No description provided for @ordersEmptyFilteredTitle.
  ///
  /// In fa, this message translates to:
  /// **'سفارشی در این دسته نیست'**
  String get ordersEmptyFilteredTitle;

  /// No description provided for @ordersEmptyFilteredBody.
  ///
  /// In fa, this message translates to:
  /// **'دسته دیگری را انتخاب کنید یا همه را ببینید.'**
  String get ordersEmptyFilteredBody;

  /// No description provided for @ordersLoadFailedTitle.
  ///
  /// In fa, this message translates to:
  /// **'سفارش‌ها بارگذاری نشد'**
  String get ordersLoadFailedTitle;

  /// No description provided for @orderSideType.
  ///
  /// In fa, this message translates to:
  /// **'{side} · {type}'**
  String orderSideType(String side, String type);

  /// No description provided for @orderQuantityLine.
  ///
  /// In fa, this message translates to:
  /// **'تعداد: {quantity} {unit}'**
  String orderQuantityLine(String quantity, String unit);

  /// No description provided for @orderFilterStatusLabel.
  ///
  /// In fa, this message translates to:
  /// **'وضعیت'**
  String get orderFilterStatusLabel;

  /// No description provided for @orderFilterAssetLabel.
  ///
  /// In fa, this message translates to:
  /// **'نوع دارایی'**
  String get orderFilterAssetLabel;

  /// No description provided for @assetAll.
  ///
  /// In fa, this message translates to:
  /// **'همه دارایی‌ها'**
  String get assetAll;

  /// No description provided for @assetStock.
  ///
  /// In fa, this message translates to:
  /// **'سهام'**
  String get assetStock;

  /// No description provided for @assetCrypto.
  ///
  /// In fa, this message translates to:
  /// **'کریپتو'**
  String get assetCrypto;

  /// No description provided for @orderRejectedReasonUnknown.
  ///
  /// In fa, this message translates to:
  /// **'سرور سفارش را نپذیرفت.'**
  String get orderRejectedReasonUnknown;

  /// No description provided for @orderLimitPrice.
  ///
  /// In fa, this message translates to:
  /// **'قیمت حدی: {price}'**
  String orderLimitPrice(String price);

  /// No description provided for @orderFilledAt.
  ///
  /// In fa, this message translates to:
  /// **'میانگین قیمت اجرا: {price}'**
  String orderFilledAt(String price);

  /// No description provided for @navSearchAdd.
  ///
  /// In fa, this message translates to:
  /// **'جستجو و افزودن'**
  String get navSearchAdd;

  /// No description provided for @unitShare.
  ///
  /// In fa, this message translates to:
  /// **'سهم'**
  String get unitShare;

  /// No description provided for @actionEdit.
  ///
  /// In fa, this message translates to:
  /// **'ویرایش'**
  String get actionEdit;

  /// No description provided for @actionDone.
  ///
  /// In fa, this message translates to:
  /// **'تمام'**
  String get actionDone;

  /// No description provided for @actionRemove.
  ///
  /// In fa, this message translates to:
  /// **'حذف از فهرست'**
  String get actionRemove;

  /// No description provided for @actionClose.
  ///
  /// In fa, this message translates to:
  /// **'بستن'**
  String get actionClose;

  /// No description provided for @actionDismiss.
  ///
  /// In fa, this message translates to:
  /// **'متوجه شدم'**
  String get actionDismiss;

  /// No description provided for @actionMoreInfo.
  ///
  /// In fa, this message translates to:
  /// **'اطلاعات بیشتر'**
  String get actionMoreInfo;

  /// No description provided for @actionCheckOrderStatus.
  ///
  /// In fa, this message translates to:
  /// **'بررسی وضعیت سفارش'**
  String get actionCheckOrderStatus;

  /// No description provided for @actionBackToList.
  ///
  /// In fa, this message translates to:
  /// **'بازگشت به فهرست'**
  String get actionBackToList;

  /// No description provided for @loadingLabel.
  ///
  /// In fa, this message translates to:
  /// **'در حال بارگذاری'**
  String get loadingLabel;

  /// No description provided for @haltedBadge.
  ///
  /// In fa, this message translates to:
  /// **'متوقف'**
  String get haltedBadge;

  /// No description provided for @haltedPriceNote.
  ///
  /// In fa, this message translates to:
  /// **'قیمت پایانی قبلی'**
  String get haltedPriceNote;

  /// No description provided for @staleBadge.
  ///
  /// In fa, this message translates to:
  /// **'قدیمی'**
  String get staleBadge;

  /// No description provided for @watchlistTitle.
  ///
  /// In fa, this message translates to:
  /// **'پیگیری قیمت‌ها'**
  String get watchlistTitle;

  /// No description provided for @watchlistEmptyTitle.
  ///
  /// In fa, this message translates to:
  /// **'فهرست پیگیری خالی است'**
  String get watchlistEmptyTitle;

  /// No description provided for @watchlistEmptyBody.
  ///
  /// In fa, this message translates to:
  /// **'برای شروع، از «جستجو و افزودن» در پایین صفحه نماد اضافه کنید.'**
  String get watchlistEmptyBody;

  /// No description provided for @watchlistLoadFailedTitle.
  ///
  /// In fa, this message translates to:
  /// **'فهرست بارگذاری نشد'**
  String get watchlistLoadFailedTitle;

  /// No description provided for @watchlistSaveRolledBack.
  ///
  /// In fa, this message translates to:
  /// **'تغییرات ذخیره نشد و فهرست به آخرین حالت ذخیره‌شده برگشت.'**
  String get watchlistSaveRolledBack;

  /// No description provided for @watchlistReorderHandle.
  ///
  /// In fa, this message translates to:
  /// **'جابه‌جایی {symbol}'**
  String watchlistReorderHandle(String symbol);

  /// No description provided for @feedConnecting.
  ///
  /// In fa, this message translates to:
  /// **'در حال اتصال به قیمت‌های زنده...'**
  String get feedConnecting;

  /// No description provided for @feedStale.
  ///
  /// In fa, this message translates to:
  /// **'قیمت‌ها ممکن است قدیمی باشند.'**
  String get feedStale;

  /// No description provided for @feedOffline.
  ///
  /// In fa, this message translates to:
  /// **'اتصال قیمت‌ها قطع است؛ در حال تلاش دوباره.'**
  String get feedOffline;

  /// No description provided for @feedLastUpdate.
  ///
  /// In fa, this message translates to:
  /// **'آخرین به‌روزرسانی: {time}'**
  String feedLastUpdate(String time);

  /// No description provided for @feedInfoTitle.
  ///
  /// In fa, this message translates to:
  /// **'وضعیت قیمت‌ها'**
  String get feedInfoTitle;

  /// No description provided for @feedInfoBody.
  ///
  /// In fa, this message translates to:
  /// **'قیمت‌ها از یک اتصال زنده می‌رسند. اگر چند ثانیه هیچ پیامی نرسد، قیمت‌ها «قدیمی» علامت می‌خورند و برنامه خودکار دوباره وصل می‌شود. سفارش‌ها همیشه با قیمت لحظه‌ای سرور اجرا می‌شوند و مبلغ‌های نمایش‌داده‌شده فقط تخمینی هستند.'**
  String get feedInfoBody;

  /// No description provided for @directionUp.
  ///
  /// In fa, this message translates to:
  /// **'افزایش'**
  String get directionUp;

  /// No description provided for @directionDown.
  ///
  /// In fa, this message translates to:
  /// **'کاهش'**
  String get directionDown;

  /// No description provided for @directionFlat.
  ///
  /// In fa, this message translates to:
  /// **'بدون تغییر'**
  String get directionFlat;

  /// No description provided for @rowSemantics.
  ///
  /// In fa, this message translates to:
  /// **'{symbol}، قیمت {price}، {direction} {change}'**
  String rowSemantics(
    String symbol,
    String price,
    String direction,
    String change,
  );

  /// No description provided for @portfolioTitle.
  ///
  /// In fa, this message translates to:
  /// **'پرتفوی'**
  String get portfolioTitle;

  /// No description provided for @portfolioCash.
  ///
  /// In fa, this message translates to:
  /// **'موجودی نقد'**
  String get portfolioCash;

  /// No description provided for @portfolioMarketValue.
  ///
  /// In fa, this message translates to:
  /// **'ارزش تقریبی دارایی‌ها'**
  String get portfolioMarketValue;

  /// No description provided for @portfolioSellNow.
  ///
  /// In fa, this message translates to:
  /// **'ارزش فروش فوری'**
  String get portfolioSellNow;

  /// No description provided for @portfolioTotal.
  ///
  /// In fa, this message translates to:
  /// **'مجموع تقریبی'**
  String get portfolioTotal;

  /// No description provided for @portfolioApproximate.
  ///
  /// In fa, this message translates to:
  /// **'برخی قیمت‌ها تقریبی هستند.'**
  String get portfolioApproximate;

  /// No description provided for @portfolioMissingPrice.
  ///
  /// In fa, this message translates to:
  /// **'برای برخی دارایی‌ها قیمتی در دسترس نیست.'**
  String get portfolioMissingPrice;

  /// No description provided for @portfolioLoadFailed.
  ///
  /// In fa, this message translates to:
  /// **'پرتفوی بارگذاری نشد.'**
  String get portfolioLoadFailed;

  /// No description provided for @portfolioInfoTitle.
  ///
  /// In fa, this message translates to:
  /// **'ارزش‌گذاری پرتفوی'**
  String get portfolioInfoTitle;

  /// No description provided for @portfolioInfoBody.
  ///
  /// In fa, this message translates to:
  /// **'ارزش تقریبی دارایی‌ها با آخرین قیمت معامله حساب می‌شود. ارزش فروش فوری با بهترین قیمت خریدار حساب می‌شود و اگر همین حالا بفروشید، مبلغ نزدیک به آن خواهد بود. برای نمادهای متوقف یا بدون قیمت زنده، قیمت پایانی قبلی استفاده می‌شود و عدد «تقریبی» است. موجودی نقد همیشه از سرور خوانده می‌شود.'**
  String get portfolioInfoBody;

  /// No description provided for @searchTitle.
  ///
  /// In fa, this message translates to:
  /// **'جستجوی نماد'**
  String get searchTitle;

  /// No description provided for @searchHint.
  ///
  /// In fa, this message translates to:
  /// **'نام یا نماد'**
  String get searchHint;

  /// No description provided for @searchPrompt.
  ///
  /// In fa, this message translates to:
  /// **'برای شروع، نام یا نماد را وارد کنید.'**
  String get searchPrompt;

  /// No description provided for @searchNoResults.
  ///
  /// In fa, this message translates to:
  /// **'نتیجه‌ای پیدا نشد.'**
  String get searchNoResults;

  /// No description provided for @searchAlreadyAdded.
  ///
  /// In fa, this message translates to:
  /// **'در فهرست است'**
  String get searchAlreadyAdded;

  /// No description provided for @ticketTitle.
  ///
  /// In fa, this message translates to:
  /// **'ثبت سفارش'**
  String get ticketTitle;

  /// No description provided for @sideBuy.
  ///
  /// In fa, this message translates to:
  /// **'خرید'**
  String get sideBuy;

  /// No description provided for @sideSell.
  ///
  /// In fa, this message translates to:
  /// **'فروش'**
  String get sideSell;

  /// No description provided for @typeMarket.
  ///
  /// In fa, this message translates to:
  /// **'بازار'**
  String get typeMarket;

  /// No description provided for @typeLimit.
  ///
  /// In fa, this message translates to:
  /// **'حدی'**
  String get typeLimit;

  /// No description provided for @quantityLabel.
  ///
  /// In fa, this message translates to:
  /// **'تعداد'**
  String get quantityLabel;

  /// No description provided for @limitPriceLabel.
  ///
  /// In fa, this message translates to:
  /// **'قیمت حدی'**
  String get limitPriceLabel;

  /// No description provided for @estimatedAmount.
  ///
  /// In fa, this message translates to:
  /// **'مبلغ تخمینی'**
  String get estimatedAmount;

  /// No description provided for @estimatedUnavailable.
  ///
  /// In fa, this message translates to:
  /// **'قیمتی برای تخمین در دسترس نیست.'**
  String get estimatedUnavailable;

  /// No description provided for @costBasisAsk.
  ///
  /// In fa, this message translates to:
  /// **'بر اساس قیمت فروشنده'**
  String get costBasisAsk;

  /// No description provided for @costBasisBid.
  ///
  /// In fa, this message translates to:
  /// **'بر اساس قیمت خریدار'**
  String get costBasisBid;

  /// No description provided for @costBasisLimit.
  ///
  /// In fa, this message translates to:
  /// **'بر اساس قیمت حدی'**
  String get costBasisLimit;

  /// No description provided for @costBasisLast.
  ///
  /// In fa, this message translates to:
  /// **'بر اساس آخرین قیمت'**
  String get costBasisLast;

  /// No description provided for @estimateStaleNote.
  ///
  /// In fa, this message translates to:
  /// **'قیمت قدیمی است؛ مبلغ دقیق نیست.'**
  String get estimateStaleNote;

  /// No description provided for @submitOrder.
  ///
  /// In fa, this message translates to:
  /// **'ارسال سفارش'**
  String get submitOrder;

  /// No description provided for @ticketOfflineBlocked.
  ///
  /// In fa, this message translates to:
  /// **'تا برقراری دوباره اتصال قیمت‌ها امکان ثبت سفارش نیست.'**
  String get ticketOfflineBlocked;

  /// No description provided for @validationRequired.
  ///
  /// In fa, this message translates to:
  /// **'این فیلد الزامی است.'**
  String get validationRequired;

  /// No description provided for @validationInvalidCharacters.
  ///
  /// In fa, this message translates to:
  /// **'فقط عدد وارد کنید و برای اعشار از نقطه استفاده کنید.'**
  String get validationInvalidCharacters;

  /// No description provided for @validationTooLong.
  ///
  /// In fa, this message translates to:
  /// **'عدد خیلی طولانی است.'**
  String get validationTooLong;

  /// No description provided for @validationTooPrecise.
  ///
  /// In fa, this message translates to:
  /// **'تعداد ارقام اعشار زیاد است.'**
  String get validationTooPrecise;

  /// No description provided for @validationNotPositive.
  ///
  /// In fa, this message translates to:
  /// **'عدد باید بزرگ‌تر از صفر باشد.'**
  String get validationNotPositive;

  /// No description provided for @validationNotMultipleOfLot.
  ///
  /// In fa, this message translates to:
  /// **'تعداد باید مضرب {step} باشد.'**
  String validationNotMultipleOfLot(String step);

  /// No description provided for @validationNotMultipleOfTick.
  ///
  /// In fa, this message translates to:
  /// **'قیمت باید مضرب {step} باشد.'**
  String validationNotMultipleOfTick(String step);

  /// No description provided for @orderSending.
  ///
  /// In fa, this message translates to:
  /// **'در حال ارسال سفارش...'**
  String get orderSending;

  /// No description provided for @orderChecking.
  ///
  /// In fa, this message translates to:
  /// **'در حال بررسی سفارش‌های قبلی...'**
  String get orderChecking;

  /// No description provided for @orderResolving.
  ///
  /// In fa, this message translates to:
  /// **'پاسخی نرسید؛ وضعیت سفارش در حال بررسی است. لطفاً صبر کنید و سفارش را دوباره ارسال نکنید.'**
  String get orderResolving;

  /// No description provided for @orderResolvingAttempt.
  ///
  /// In fa, this message translates to:
  /// **'تلاش شماره {attempt}'**
  String orderResolvingAttempt(String attempt);

  /// No description provided for @orderUnresolvedTitle.
  ///
  /// In fa, this message translates to:
  /// **'وضعیت سفارش هنوز مشخص نیست'**
  String get orderUnresolvedTitle;

  /// No description provided for @orderUnresolvedBody.
  ///
  /// In fa, this message translates to:
  /// **'ممکن است سفارش اجرا شده باشد. تا مشخص شدن وضعیت، سفارش جدیدی برای این نماد ثبت نکنید.'**
  String get orderUnresolvedBody;

  /// No description provided for @orderFilledTitle.
  ///
  /// In fa, this message translates to:
  /// **'سفارش اجرا شد'**
  String get orderFilledTitle;

  /// No description provided for @holdingLabel.
  ///
  /// In fa, this message translates to:
  /// **'موجودی شما: {quantity} {unit}'**
  String holdingLabel(String quantity, String unit);

  /// No description provided for @holdingNone.
  ///
  /// In fa, this message translates to:
  /// **'موجودی شما: ندارید'**
  String get holdingNone;

  /// No description provided for @availableToBuy.
  ///
  /// In fa, this message translates to:
  /// **'قابل خرید: {amount}'**
  String availableToBuy(String amount);

  /// No description provided for @availableToBuyMax.
  ///
  /// In fa, this message translates to:
  /// **'حداکثر تعداد: {quantity} {unit}'**
  String availableToBuyMax(String quantity, String unit);

  /// No description provided for @availableToSell.
  ///
  /// In fa, this message translates to:
  /// **'قابل فروش: {quantity} {unit}'**
  String availableToSell(String quantity, String unit);

  /// No description provided for @availableToSellNone.
  ///
  /// In fa, this message translates to:
  /// **'چیزی برای فروش ندارید.'**
  String get availableToSellNone;

  /// No description provided for @actionMax.
  ///
  /// In fa, this message translates to:
  /// **'حداکثر'**
  String get actionMax;

  /// No description provided for @holdingsTitle.
  ///
  /// In fa, this message translates to:
  /// **'دارایی‌های شما'**
  String get holdingsTitle;

  /// No description provided for @holdingsEmpty.
  ///
  /// In fa, this message translates to:
  /// **'هنوز دارایی‌ای ندارید.'**
  String get holdingsEmpty;

  /// No description provided for @holdingValue.
  ///
  /// In fa, this message translates to:
  /// **'حدود {value}'**
  String holdingValue(String value);

  /// No description provided for @watchlistAssetEmpty.
  ///
  /// In fa, this message translates to:
  /// **'در این دسته نمادی ندارید.'**
  String get watchlistAssetEmpty;

  /// No description provided for @orderFilledBody.
  ///
  /// In fa, this message translates to:
  /// **'{quantity} {unit} از {symbol} با میانگین قیمت {price} اجرا شد.'**
  String orderFilledBody(
    String quantity,
    String unit,
    String symbol,
    String price,
  );

  /// No description provided for @orderWorkingTitle.
  ///
  /// In fa, this message translates to:
  /// **'سفارش در صف است'**
  String get orderWorkingTitle;

  /// No description provided for @orderWorkingBody.
  ///
  /// In fa, this message translates to:
  /// **'سفارش ثبت شد و هنوز اجرا نشده است.'**
  String get orderWorkingBody;

  /// No description provided for @orderRejectedTitle.
  ///
  /// In fa, this message translates to:
  /// **'سفارش ثبت نشد'**
  String get orderRejectedTitle;

  /// No description provided for @recoveryFilled.
  ///
  /// In fa, this message translates to:
  /// **'سفارش قبلی {symbol} اجرا شده بود.'**
  String recoveryFilled(String symbol);

  /// No description provided for @recoveryWorking.
  ///
  /// In fa, this message translates to:
  /// **'سفارش قبلی {symbol} در صف است.'**
  String recoveryWorking(String symbol);

  /// No description provided for @recoveryNotExecuted.
  ///
  /// In fa, this message translates to:
  /// **'سفارش قبلی {symbol} اجرا نشده بود.'**
  String recoveryNotExecuted(String symbol);

  /// No description provided for @recoveryStillUnresolved.
  ///
  /// In fa, this message translates to:
  /// **'وضعیت سفارش قبلی {symbol} هنوز نامشخص است.'**
  String recoveryStillUnresolved(String symbol);

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In fa, this message translates to:
  /// **'سرویس موقتاً در دسترس نیست. دوباره تلاش می‌کنیم.'**
  String get errorServiceUnavailable;

  /// No description provided for @errorTimeout.
  ///
  /// In fa, this message translates to:
  /// **'پاسخی دریافت نشد. وضعیت در حال بررسی است.'**
  String get errorTimeout;

  /// No description provided for @errorInsufficientFunds.
  ///
  /// In fa, this message translates to:
  /// **'موجودی کافی نیست.'**
  String get errorInsufficientFunds;

  /// No description provided for @errorInsufficientPosition.
  ///
  /// In fa, this message translates to:
  /// **'مقدار دارایی برای فروش کافی نیست.'**
  String get errorInsufficientPosition;

  /// No description provided for @errorTradingHalted.
  ///
  /// In fa, this message translates to:
  /// **'معامله این نماد متوقف است.'**
  String get errorTradingHalted;

  /// No description provided for @errorWatchlistFull.
  ///
  /// In fa, this message translates to:
  /// **'فهرست پیگیری پر است (حداکثر {max} نماد).'**
  String errorWatchlistFull(String max);

  /// No description provided for @errorUnknownSymbol.
  ///
  /// In fa, this message translates to:
  /// **'نماد پیدا نشد.'**
  String get errorUnknownSymbol;

  /// No description provided for @errorNotFound.
  ///
  /// In fa, this message translates to:
  /// **'مورد درخواستی پیدا نشد.'**
  String get errorNotFound;

  /// No description provided for @errorInvalidQuantity.
  ///
  /// In fa, this message translates to:
  /// **'مقدار واردشده معتبر نیست.'**
  String get errorInvalidQuantity;

  /// No description provided for @errorInvalidPrice.
  ///
  /// In fa, this message translates to:
  /// **'قیمت واردشده معتبر نیست.'**
  String get errorInvalidPrice;

  /// No description provided for @errorInvalidRequest.
  ///
  /// In fa, this message translates to:
  /// **'درخواست نامعتبر است.'**
  String get errorInvalidRequest;

  /// No description provided for @errorIdempotencyConflict.
  ///
  /// In fa, this message translates to:
  /// **'این سفارش با اطلاعات دیگری قبلاً ثبت شده است.'**
  String get errorIdempotencyConflict;

  /// No description provided for @errorConnectionLost.
  ///
  /// In fa, this message translates to:
  /// **'اتصال قطع شد. در حال اتصال دوباره...'**
  String get errorConnectionLost;

  /// No description provided for @errorParsing.
  ///
  /// In fa, this message translates to:
  /// **'داده دریافتی قابل پردازش نیست.'**
  String get errorParsing;

  /// No description provided for @errorStorage.
  ///
  /// In fa, this message translates to:
  /// **'ذخیره‌سازی روی دستگاه ناموفق بود؛ سفارش ارسال نشد.'**
  String get errorStorage;

  /// No description provided for @errorValidation.
  ///
  /// In fa, this message translates to:
  /// **'اطلاعات واردشده معتبر نیست.'**
  String get errorValidation;

  /// No description provided for @errorDuplicateSymbol.
  ///
  /// In fa, this message translates to:
  /// **'این نماد قبلاً در فهرست است.'**
  String get errorDuplicateSymbol;

  /// No description provided for @errorUnknownServer.
  ///
  /// In fa, this message translates to:
  /// **'خطای ناشناخته از سرور.'**
  String get errorUnknownServer;

  /// No description provided for @errorUnexpected.
  ///
  /// In fa, this message translates to:
  /// **'خطای غیرمنتظره رخ داد.'**
  String get errorUnexpected;

  /// No description provided for @chartTitle.
  ///
  /// In fa, this message translates to:
  /// **'نمودار قیمت'**
  String get chartTitle;

  /// No description provided for @rangeDay.
  ///
  /// In fa, this message translates to:
  /// **'روز'**
  String get rangeDay;

  /// No description provided for @rangeWeek.
  ///
  /// In fa, this message translates to:
  /// **'هفته'**
  String get rangeWeek;

  /// No description provided for @rangeMonth.
  ///
  /// In fa, this message translates to:
  /// **'ماه'**
  String get rangeMonth;

  /// No description provided for @chartEmpty.
  ///
  /// In fa, this message translates to:
  /// **'داده‌ای برای نمودار وجود ندارد.'**
  String get chartEmpty;

  /// No description provided for @chartLegend.
  ///
  /// In fa, this message translates to:
  /// **'شمع توخالی = صعودی، شمع توپر = نزولی'**
  String get chartLegend;

  /// No description provided for @chartSummary.
  ///
  /// In fa, this message translates to:
  /// **'نمودار شمعی {symbol}: {count} شمع، پایین‌ترین {low}، بالاترین {high}'**
  String chartSummary(String symbol, String count, String low, String high);

  /// No description provided for @chartSelected.
  ///
  /// In fa, this message translates to:
  /// **'{time} · باز {open} · بالا {high} · پایین {low} · بسته {close}'**
  String chartSelected(
    String time,
    String open,
    String high,
    String low,
    String close,
  );

  /// No description provided for @selectInstrumentTitle.
  ///
  /// In fa, this message translates to:
  /// **'یک نماد را انتخاب کنید'**
  String get selectInstrumentTitle;

  /// No description provided for @selectInstrumentBody.
  ///
  /// In fa, this message translates to:
  /// **'برای دیدن نمودار و ثبت سفارش، نماد را از فهرست انتخاب کنید.'**
  String get selectInstrumentBody;

  /// No description provided for @switchBlocked.
  ///
  /// In fa, this message translates to:
  /// **'تا مشخص شدن وضعیت سفارش جاری، نماد دیگری را انتخاب نکنید.'**
  String get switchBlocked;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['fa'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'fa':
      return AppLocalizationsFa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
