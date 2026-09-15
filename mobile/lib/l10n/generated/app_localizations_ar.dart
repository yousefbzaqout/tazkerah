// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'تذكرة';

  @override
  String get commonRetry => 'إعادة المحاولة';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonOk => 'حسناً';

  @override
  String get errorNetwork =>
      'لا يوجد اتصال بالإنترنت. تحقق من الشبكة وحاول مرة أخرى.';

  @override
  String get errorTimeout =>
      'استغرق الطلب وقتاً طويلاً. يرجى المحاولة مرة أخرى.';

  @override
  String get errorServer => 'حدث خطأ لدينا. يرجى المحاولة بعد قليل.';

  @override
  String get errorUnauthorized => 'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get errorUnexpected => 'حدث خطأ غير متوقع.';

  @override
  String get stateEmptyTitle => 'لا يوجد شيء هنا بعد';

  @override
  String get stateOfflineBanner => 'أنت غير متصل. يتم عرض البيانات المحفوظة.';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsThemeSystem => 'إعدادات النظام';

  @override
  String get settingsThemeLight => 'فاتح';

  @override
  String get settingsThemeDark => 'داكن';

  @override
  String get appTitleLatin => 'Tazkerah';

  @override
  String get authBrandNameArabic => 'تذكرة';

  @override
  String get authTagline =>
      'ادخل إلى تصاريحك الرقمية الآمنة وبوابات الدخول المشفّرة.';

  @override
  String get authIdentifierLabel => 'البريد الإلكتروني أو الجوال';

  @override
  String get authIdentifierHint => 'name@domain.com أو ‎+966...';

  @override
  String get authContinue => 'متابعة';

  @override
  String get authOfflineBadge => 'غير متصل — يلزم اتصال بالشبكة';

  @override
  String get authOfflineExplanation =>
      'الشبكة غير متاحة. يلزم اتصال فعّال بالإنترنت للتحقق من هويتك وإصدار تصاريح الدخول المشفّرة.';

  @override
  String get authCheckConnection => 'إعادة فحص الاتصال';

  @override
  String get authIdentifierRequired => 'أدخل بريدك الإلكتروني أو رقم جوالك.';

  @override
  String get authIdentifierInvalid =>
      'أدخل بريداً إلكترونياً أو رقم جوال صحيحاً.';

  @override
  String get legalTerms => 'شروط الخدمة';

  @override
  String get legalPrivacy => 'سياسة الخصوصية';

  @override
  String get eventsEyebrow => 'بوابات دخول حصرية';

  @override
  String get eventsLivePasses => 'تصاريح نشطة';

  @override
  String get navEvents => 'الفعاليات';

  @override
  String get navTickets => 'تذاكري';

  @override
  String get navConcierge => 'المساعد';

  @override
  String get navProfile => 'حسابي';

  @override
  String get routeNotFoundTitle => 'الصفحة غير موجودة';

  @override
  String get routeNotFoundMessage => 'الرابط الذي فتحته لا يؤدي إلى أي صفحة.';

  @override
  String get routeGoHome => 'الذهاب إلى الرئيسية';

  @override
  String get otpTitle => 'رمز التحقق';

  @override
  String get otpCodeLabel => 'رمز التحقق';

  @override
  String get otpDigitsHint => '٦ أرقام';

  @override
  String get otpEdit => 'تعديل';

  @override
  String get otpNoCode => 'لم يصلك الرمز؟';

  @override
  String get otpResend => 'إعادة إرسال الرمز';

  @override
  String otpResendIn(int seconds) {
    return 'إعادة الإرسال خلال $seconds ثانية';
  }

  @override
  String get otpVerify => 'تحقّق';

  @override
  String get otpInvalid => 'رمز غير صحيح. حاول مرة أخرى.';

  @override
  String get otpExpired => 'انتهت صلاحية الرمز. اطلب رمزاً جديداً.';

  @override
  String get otpTooManyAttempts => 'محاولات كثيرة. حاول لاحقاً.';

  @override
  String get otpResent => 'تم إرسال رمز جديد.';

  @override
  String get discoveryTitle => 'اختر تجربتك';

  @override
  String get discoveryCacheEyebrow => 'ذاكرة مؤقتة مشفّرة محليًا';

  @override
  String get discoverySynchronizing => 'جارٍ المزامنة...';

  @override
  String discoveryPassesReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تذكرة جاهزة',
      many: '$count تذكرة جاهزة',
      few: '$count تذاكر جاهزة',
      two: 'تذكرتان جاهزتان',
      one: 'تذكرة واحدة جاهزة',
      zero: 'لا تذاكر جاهزة',
    );
    return '$_temp0';
  }

  @override
  String get discoveryOfflineBanner => 'غير متصل — يتم عرض فعاليات محفوظة';

  @override
  String discoveryLastSynchronized(String duration) {
    return 'آخر مزامنة قبل $duration';
  }

  @override
  String get discoveryReconnect => 'إعادة الاتصال';

  @override
  String get discoverySearchHint => 'ابحث عن فعاليات أو أماكن أو مدن';

  @override
  String get discoverySearchClear => 'مسح البحث';

  @override
  String get discoveryPriceFrom => 'تبدأ من';

  @override
  String discoveryPrice(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String get discoverySoldOut => 'نفدت التذاكر';

  @override
  String get discoveryCachedTag => 'محفوظة';

  @override
  String get discoveryEmptyTitle => 'لا توجد فعاليات';

  @override
  String get discoveryEmptyMessage =>
      'لا توجد نتائج مطابقة لبحثك حاليًا. جرّب كلمة أخرى.';

  @override
  String get discoveryEmptyFeedMessage =>
      'لا توجد فعاليات معروضة حاليًا. عد إلينا قريبًا.';

  @override
  String discoveryVenueSeparator(String venue, String city) {
    return '$venue • $city';
  }

  @override
  String discoveryEventCardLabel(String title, String date, String price) {
    return '$title، $date، تبدأ من $price';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes دقيقة';
  }

  @override
  String durationHours(int hours) {
    return '$hours ساعة';
  }

  @override
  String durationDays(int days) {
    return '$days يوم';
  }

  @override
  String get detailOfficialGateEntry => 'دخول رسمي للبوابة';

  @override
  String get detailDateTimeLabel => 'التاريخ والوقت';

  @override
  String get detailLocationLabel => 'الموقع';

  @override
  String get detailOverviewLabel => 'نبذة';

  @override
  String detailGatesAt(String time, String zone, String doors) {
    return '$time $zone (فتح البوابات $doors)';
  }

  @override
  String detailTimeNoGates(String time, String zone) {
    return '$time $zone';
  }

  @override
  String get detailStartingFrom => 'تبدأ من';

  @override
  String get detailFeesIncluded => 'شامل ضريبة القيمة المضافة ورسوم البوابة';

  @override
  String get detailSelectSeats => 'اختيار المقاعد';

  @override
  String get detailSoldOut => 'نفدت التذاكر';

  @override
  String get detailNotOnSale => 'لم يبدأ البيع بعد';

  @override
  String get detailAntiPassback => 'منع إعادة التمرير مفعّل';

  @override
  String get detailShare => 'مشاركة الفعالية';

  @override
  String get detailBack => 'رجوع';

  @override
  String get detailMissingTitle => 'الفعالية غير متاحة';

  @override
  String get detailMissingMessage =>
      'قد تكون الفعالية قد انتهت أو أن الرابط لم يعد صالحًا.';

  @override
  String get detailBrowseEvents => 'تصفّح الفعاليات';

  @override
  String get detailSeatSelectionSoon =>
      'سيتاح اختيار المقاعد في الإصدار القادم.';

  @override
  String get detailShareSoon => 'ستتاح المشاركة في الإصدار القادم.';

  @override
  String get errorLocked => 'هذا القسم غير متاح للحجز.';

  @override
  String get seatLegendAvailable => 'متاح';

  @override
  String get seatLegendTaken => 'محجوز';

  @override
  String get seatLegendConflict => 'تعارض (409)';

  @override
  String get seatLegendHeld => 'محجوز لك';

  @override
  String get seatLegendSold => 'مُباع';

  @override
  String get seatStage => 'المسرح / العرض';

  @override
  String get seatStagePodium => 'المسرح / المنصة الرئيسية';

  @override
  String get seatTakenTag => 'محجوز';

  @override
  String get seatStatusLive => 'مزامنة حية';

  @override
  String get seatStatusLabel => 'الحالة';

  @override
  String get seatCurrentSelection => 'الاختيار الحالي';

  @override
  String get seatNoSelection => 'لم يتم اختيار مقعد';

  @override
  String get seatSubtotal => 'المجموع';

  @override
  String get seatSelectPrompt => 'اختر مقعدًا متاحًا';

  @override
  String get seatHoldSeat => 'حجز المقعد';

  @override
  String get seatConflictEyebrow => 'تعارض · HTTP 409';

  @override
  String get seatConflictTitle => 'تم حجز المقعد للتو — اختر غيره';

  @override
  String get seatConflictMessage =>
      'أكمل ضيف آخر الحجز لهذا المقعد قبل أجزاء من الثانية. تم مسح اختيارك.';

  @override
  String seatConflictSeat(String seat) {
    return 'مقعد $seat';
  }

  @override
  String get seatLockedStatus => 'HTTP 423 · مقفل';

  @override
  String get seatLockedTitle => 'القسم مقفل من قبل المنظّم';

  @override
  String seatLockedMessage(String sector) {
    return '$sector محجوز حاليًا لتخصيص الإنتاج أو لضيوف الفنان. لا يمكن حجز مقاعد فردية.';
  }

  @override
  String get seatLockedTargetLabel => 'القسم المطلوب';

  @override
  String get seatLockedReasonLabel => 'سبب الإقفال';

  @override
  String get seatLockedAlternativesLabel => 'البدائل المتاحة';

  @override
  String get seatChooseAnotherSector => 'اختر قسمًا آخر';

  @override
  String get seatViewAvailableOnly => 'عرض الأقسام المتاحة فقط';

  @override
  String seatHeldBadge(String reference) {
    return 'محجوز ($reference)';
  }

  @override
  String get seatSeatsHeld => 'المقاعد المحجوزة';

  @override
  String get seatLockedToOrder => 'مرتبط بالطلب';

  @override
  String get seatSelectionLockedNote => 'اختيار المقاعد مقفل أثناء عمل المؤقّت';

  @override
  String get seatAssignedSelection => 'المقعد المخصص';

  @override
  String get seatTotalPrice => 'السعر الإجمالي';

  @override
  String get seatFeesNote => 'شامل ضريبة القيمة المضافة ودخول البوابة';

  @override
  String get seatContinueCheckout => 'متابعة الدفع';

  @override
  String seatRowSeatCaption(String row, String seat) {
    return '(صف $row، مقعد $seat)';
  }

  @override
  String get seatUnavailableInTier => 'غير متاح في هذه الفئة';

  @override
  String get seatHoldExpiredTitle => 'انتهت مدة الحجز';

  @override
  String get seatHoldExpiredMessage =>
      'تم تحرير مقاعدك. اختر من جديد للمتابعة.';

  @override
  String get seatChooseAgain => 'اختر من جديد';

  @override
  String get seatDismiss => 'إغلاق';

  @override
  String get checkoutTitle => 'إتمام الطلب';

  @override
  String get checkoutWindowActive => 'نافذة الدفع مفتوحة';

  @override
  String checkoutWindowExtended(int minutes) {
    return 'تم تمديد الحجز $minutes دقائق لإتمام الدفع';
  }

  @override
  String get checkoutConfirmedReservation => 'الحجز المؤكد';

  @override
  String get checkoutSeatReserved => 'المقعد المحجوز';

  @override
  String get checkoutPriceBreakdown => 'تفاصيل السعر';

  @override
  String checkoutVatRegistration(String number) {
    return 'الرقم الضريبي $number';
  }

  @override
  String get checkoutTotalAmount => 'المبلغ الإجمالي';

  @override
  String checkoutPayNow(String amount, String currency) {
    return 'ادفع الآن · $amount $currency';
  }

  @override
  String get checkoutCancelHold => 'إلغاء الحجز';

  @override
  String get checkoutCancelTitle => 'تحرير مقاعدك؟';

  @override
  String get checkoutCancelMessage =>
      'ستعود مقاعدك المحجوزة إلى المخزون العام وقد يحجزها شخص آخر.';

  @override
  String get checkoutCancelConfirm => 'تحرير المقاعد';

  @override
  String get checkoutKeepHold => 'الاحتفاظ بمقاعدي';

  @override
  String get checkoutSessionTimeout => 'انتهت الجلسة';

  @override
  String get checkoutHoldTimer => 'مؤقّت الحجز';

  @override
  String get checkoutExpiredTitle => 'انتهت مدة الحجز —';

  @override
  String get checkoutExpiredTitleAccent => 'تم تحرير المقاعد';

  @override
  String get checkoutExpiredMessage =>
      'وصلت نافذة الحجز المؤقت إلى الصفر. لضمان وصول عادل للفعاليات عالية الطلب، أُعيدت المقاعد المحجوزة سابقًا إلى المخزون العام.';

  @override
  String get checkoutReleasedReservation => 'الحجز المُحرَّر';

  @override
  String get checkoutExpiredTag => 'منتهٍ';

  @override
  String checkoutHeldSeat(String seat) {
    return 'المقعد المحجوز: $seat';
  }

  @override
  String checkoutPolicyNote(String code) {
    return '$code: سياسة صارمة لدورة حياة المقعد';
  }

  @override
  String get checkoutSelectSeatsAgain => 'اختر المقاعد مرة أخرى';

  @override
  String get checkoutReturnToEvent => 'العودة إلى صفحة الفعالية';

  @override
  String get checkoutPaymentUnavailable =>
      'تعذّر بدء عملية الدفع. يرجى المحاولة مرة أخرى.';

  @override
  String get checkoutGatewayOpens => 'جارٍ فتح الدفع الآمن…';

  @override
  String get passActiveBadge => 'تصريح دخول فعّال';

  @override
  String passReferenceLine(String reference) {
    return '$reference · TOTP';
  }

  @override
  String get passSeatLabel => 'المقعد';

  @override
  String get passHighLuminosity => 'تم رفع سطوع الشاشة';

  @override
  String get passCardBrand => 'TAZKERAH';

  @override
  String get passDynamicPass => 'تصريح ديناميكي';

  @override
  String passSecondsRemaining(int seconds) {
    return '$seconds ث';
  }

  @override
  String get passRemainingSuffix => 'متبقية';

  @override
  String passRefreshNote(int seconds) {
    return 'يتجدد الرمز كل $seconds ثانية';
  }

  @override
  String get passSecurityNote =>
      'علامة مائية ضد لقطات الشاشة · دخول لمرة واحدة فقط';

  @override
  String get passHolder => 'حامل التذكرة';

  @override
  String get passEntrance => 'المدخل';

  @override
  String get passStatusRow => 'الحالة';

  @override
  String passFastTrack(String gate) {
    return '$gate · مسار سريع';
  }

  @override
  String get passOnlineValidated => 'تم التحقق عبر الإنترنت';

  @override
  String get passScannerHint => 'ضع الهاتف مباشرة فوق زجاج الماسح';

  @override
  String get passClockStale =>
      'ساعة الجهاز غير متزامنة. قد ترفض البوابة هذا الرمز.';

  @override
  String get passInterceptEyebrow => 'اعتراض أمني';

  @override
  String get passInterceptJustNow => 'الآن';

  @override
  String get passInterceptTitle =>
      'تم رصد لقطة شاشة: جرى تحديث الرمز لأسباب أمنية.';

  @override
  String get passInterceptMessage =>
      'النسخ الثابتة غير صالحة عند البوابة. اضغط لعرض رمز جديد.';

  @override
  String get passRedacted => 'تم إخفاء المحتوى';

  @override
  String passRedactedHash(String hash) {
    return 'البصمة: $hash';
  }

  @override
  String get passAntiScreenshotGuard => 'حماية ضد لقطات الشاشة';

  @override
  String get passRekeying => 'إعادة توليد المفتاح:';

  @override
  String get passNewTokenReady => 'رمز جديد جاهز';

  @override
  String passRollingNote(int seconds) {
    return 'تذكرة متجددة · دورة TOTP صارمة كل $seconds ثانية';
  }

  @override
  String get passVenueEntry => 'مدخل المكان';

  @override
  String get passValidation => 'التحقق';

  @override
  String get passSynced => 'متزامن';

  @override
  String get passDeviceId => 'معرّف الجهاز';

  @override
  String get passRevealFresh => 'عرض رمز جديد';

  @override
  String get passSecuredBy =>
      'محمي ببروتوكول Tazkerah لمنع إعادة التمرير و TOTP في الذاكرة';

  @override
  String get passConfirmedAccess => 'دخول مؤكد · تصريح TOTP آمن';

  @override
  String passZoneSeat(String zone, String seat) {
    return 'المنطقة: $zone · المقعد: $seat';
  }

  @override
  String get passUnavailableTitle => 'التصريح غير متاح';

  @override
  String get passUnavailableConsumed =>
      'تم استخدام هذا التصريح بالفعل. الدخول لمرة واحدة فقط.';

  @override
  String get passUnavailableInvalid => 'لم يعد هذا التصريح صالحًا.';

  @override
  String passSkewBadge(int seconds) {
    return 'انحراف > $seconds ث';
  }

  @override
  String passAuthProtocol(String reference) {
    return '$reference · بروتوكول مصادقة البوابة';
  }

  @override
  String get passSkewTitle => 'وقت الجهاز غير متزامن';

  @override
  String passSkewMessage(int seconds, String policy) {
    return 'تجاوز انحراف الساعة $seconds ثانية. تم إخفاء رمز QR الديناميكي حفاظًا على سلامة الدخول وفق سياسة الأمان $policy.';
  }

  @override
  String get passHolderLabel => 'حامل التصريح';

  @override
  String get passAssignedSeat => 'المقعد المخصص';

  @override
  String passQrSuppressed(String policy) {
    return 'تم إخفاء رمز QR ($policy)';
  }

  @override
  String get passManualCodeLabel => 'رمز الدخول اليدوي البديل';

  @override
  String get passManualCodeHelp =>
      'قدّم رمز الطوارئ المكوّن من 8 أرقام مباشرةً إلى الموظف عند بوابة الدخول للتحقق اليدوي.';

  @override
  String passOffsetReadout(String offset) {
    return 'الإزاحة: $offset';
  }

  @override
  String passHashReadout(String hash) {
    return 'البصمة: $hash';
  }

  @override
  String get passResyncAction => 'محاولة إعادة مزامنة الوقت';

  @override
  String get passStaffOverride =>
      'يمكن لموظفي البوابة الإدخال اليدوي عبر لوحة المفاتيح';

  @override
  String get passResyncFailed =>
      'تعذّر الوصول إلى خادم الوقت. الرمز البديل ما زال صالحًا.';

  @override
  String get passResyncStillSkewed =>
      'الساعة ما زالت غير متزامنة. واصل استخدام الرمز البديل.';

  @override
  String get walletTitle => 'تذاكري';

  @override
  String get walletUpcoming => 'القادمة';

  @override
  String get walletPast => 'السابقة';

  @override
  String get walletEmptyTitle => 'لا توجد تذاكر بعد';

  @override
  String get walletEmptyMessage =>
      'ستظهر هنا التذاكر التي تشتريها، جاهزة للعرض عند البوابة.';

  @override
  String get walletBrowseEvents => 'تصفّح الفعاليات';

  @override
  String get walletStatusValid => 'صالحة';

  @override
  String get walletStatusUsed => 'مستخدمة';

  @override
  String get walletStatusRefunded => 'مستردة';

  @override
  String get walletStatusExpired => 'منتهية';

  @override
  String ticketOrderReference(String reference) {
    return 'الطلب $reference';
  }

  @override
  String get ticketSeatLabel => 'المقعد';

  @override
  String get ticketZoneLabel => 'المنطقة';

  @override
  String get ticketGateLabel => 'البوابة';

  @override
  String get ticketPaidLabel => 'المدفوع';

  @override
  String ticketPurchasedOn(String date) {
    return 'تم الشراء في $date';
  }

  @override
  String get ticketPresentAction => 'العرض عند البوابة';

  @override
  String get ticketCannotPresent => 'لم يعد بالإمكان عرض هذه التذكرة.';

  @override
  String get ticketMissingTitle => 'التذكرة غير موجودة';

  @override
  String get ticketMissingMessage =>
      'قد تكون التذكرة قد نُقلت أو أن الرابط لم يعد صالحًا.';

  @override
  String get ticketViewEvent => 'عرض الفعالية';

  @override
  String get confirmationSettlingTitle => 'جارٍ تأكيد عملية الدفع';

  @override
  String get confirmationSettlingMessage =>
      'يستغرق ذلك عادةً بضع ثوانٍ. لا تغلق التطبيق.';

  @override
  String get confirmationTitle => 'تم تأكيد الشراء';

  @override
  String get confirmationMessage =>
      'تذكرتك جاهزة. اعرضها عند البوابة لدى وصولك.';

  @override
  String get confirmationViewTicket => 'عرض تذكرتي';

  @override
  String get confirmationGoToWallet => 'الذهاب إلى تذاكري';

  @override
  String get confirmationPendingTitle => 'الدفع يستغرق وقتًا أطول من المعتاد';

  @override
  String get confirmationPendingMessage =>
      'إذا تمت عملية الدفع بنجاح، ستظهر تذكرتك في «تذاكري» قريبًا. لم يتم خصم المبلغ مرتين.';

  @override
  String get conciergeTitle => 'المساعد';

  @override
  String get conciergeSubtitle => 'اسأل عن البوابات والمقاعد وتذاكرك';

  @override
  String get conciergeEmptyTitle => 'كيف يمكنني المساعدة؟';

  @override
  String get conciergeEmptyMessage =>
      'اسأل عن مواعيد فتح البوابات، أو موقع مقعدك، أو ما تشمله تذكرتك.';

  @override
  String get conciergeComposerHint => 'اطرح سؤالًا';

  @override
  String get conciergeSend => 'إرسال';

  @override
  String get conciergeThinking => 'جارٍ التفكير…';

  @override
  String get conciergeInterrupted => 'انقطعت الإجابة';

  @override
  String get conciergeRetry => 'إعادة المحاولة';

  @override
  String get conciergeSources => 'المصادر';

  @override
  String get conciergeOfflineTitle => 'المساعد يحتاج إلى اتصال';

  @override
  String get conciergeOfflineMessage =>
      'يتم البحث عن الإجابات على خوادمنا، لذا لا يعمل المساعد دون اتصال. تذاكرك تبقى متاحة في «تذاكري».';

  @override
  String get conciergeClear => 'مسح المحادثة';

  @override
  String get conciergeDisclaimer =>
      'قد تكون الإجابات غير كاملة. راجع تذكرتك للتفاصيل النهائية.';

  @override
  String get conciergeSuggestionGates => 'متى تُفتح البوابات؟';

  @override
  String get conciergeSuggestionSeat => 'أين مقعدي؟';

  @override
  String get conciergeSuggestionRefund => 'ما سياسة الاسترداد؟';

  @override
  String get profileTitle => 'الملف الشخصي';

  @override
  String get profileAccountSection => 'الحساب';

  @override
  String get profileSecuritySection => 'الأمان';

  @override
  String get profileAppSection => 'التطبيق';

  @override
  String get profileEmailLabel => 'البريد الإلكتروني';

  @override
  String get profilePhoneLabel => 'رقم الجوال';

  @override
  String profileMemberSince(String date) {
    return 'عضو منذ $date';
  }

  @override
  String get profileDeviceLabel => 'هذا الجهاز';

  @override
  String get profileDeviceNote =>
      'تصاريحك مرتبطة بهذا الجهاز ولا يمكن عرضها من جهاز آخر.';

  @override
  String get profileLanguageLabel => 'اللغة';

  @override
  String get profileLanguageSystem => 'لغة النظام';

  @override
  String get profileSignOut => 'تسجيل الخروج';

  @override
  String get profileSignOutTitle => 'تسجيل الخروج من تذكرة؟';

  @override
  String get profileSignOutMessage =>
      'تبقى تذاكرك في حسابك، لكن لن يتمكن هذا الجهاز من عرضها حتى تسجّل الدخول مرة أخرى.';

  @override
  String get profileSignOutConfirm => 'تسجيل الخروج';

  @override
  String get profileStay => 'البقاء مسجّلًا';

  @override
  String profileVersion(String version, String build) {
    return 'الإصدار $version ($build)';
  }

  @override
  String get notificationChannelRemindersName => 'تذكيرات الفعاليات';

  @override
  String get notificationChannelRemindersDescription =>
      'تذكيرات قبل فعالية تملك تذكرة لها.';

  @override
  String reminderDayBeforeTitle(String eventTitle) {
    return '$eventTitle غدًا';
  }

  @override
  String reminderHoursBeforeTitle(String eventTitle) {
    return '$eventTitle تبدأ قريبًا';
  }

  @override
  String reminderBody(String time, String venue) {
    return '$time في $venue. تذكرتك داخل التطبيق.';
  }
}
