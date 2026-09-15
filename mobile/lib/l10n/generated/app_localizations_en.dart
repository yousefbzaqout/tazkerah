// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Tazkerah';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get errorNetwork =>
      'No internet connection. Check your network and try again.';

  @override
  String get errorTimeout => 'The request took too long. Please try again.';

  @override
  String get errorServer =>
      'Something went wrong on our end. Please try again shortly.';

  @override
  String get errorUnauthorized =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorUnexpected => 'An unexpected error occurred.';

  @override
  String get stateEmptyTitle => 'Nothing here yet';

  @override
  String get stateOfflineBanner => 'You are offline. Showing saved data.';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsThemeSystem => 'System default';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get appTitleLatin => 'Tazkerah';

  @override
  String get authBrandNameArabic => 'تذكرة';

  @override
  String get authTagline =>
      'Access your secure digital passes and encrypted gate entry.';

  @override
  String get authIdentifierLabel => 'EMAIL OR PHONE';

  @override
  String get authIdentifierHint => 'name@domain.com or +966...';

  @override
  String get authContinue => 'Continue';

  @override
  String get authOfflineBadge => 'Offline — Network connection required';

  @override
  String get authOfflineExplanation =>
      'Network unavailable. An active internet connection is required to authenticate your identity and issue encrypted gate passes.';

  @override
  String get authCheckConnection => 'Check connection';

  @override
  String get authIdentifierRequired => 'Enter your email or phone number.';

  @override
  String get authIdentifierInvalid =>
      'Enter a valid email address or phone number.';

  @override
  String get legalTerms => 'Terms of Service';

  @override
  String get legalPrivacy => 'Privacy Policy';

  @override
  String get eventsEyebrow => 'EXCLUSIVE GATE ENTRIES';

  @override
  String get eventsLivePasses => 'LIVE PASSES';

  @override
  String get navEvents => 'Events';

  @override
  String get navTickets => 'Tickets';

  @override
  String get navConcierge => 'Concierge';

  @override
  String get navProfile => 'Profile';

  @override
  String get routeNotFoundTitle => 'Page not found';

  @override
  String get routeNotFoundMessage =>
      'The link you followed does not lead anywhere.';

  @override
  String get routeGoHome => 'Go to home';

  @override
  String get otpTitle => 'Security code';

  @override
  String get otpCodeLabel => 'SECURITY CODE';

  @override
  String get otpDigitsHint => '6 digits';

  @override
  String get otpEdit => 'Edit';

  @override
  String get otpNoCode => 'Didn\'t receive code?';

  @override
  String get otpResend => 'Resend Code';

  @override
  String otpResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get otpVerify => 'Verify';

  @override
  String get otpInvalid => 'Invalid code. Try again.';

  @override
  String get otpExpired => 'That code expired. Request a new one.';

  @override
  String get otpTooManyAttempts => 'Too many attempts. Try again later.';

  @override
  String get otpResent => 'A new code is on its way.';

  @override
  String get discoveryTitle => 'Select Experience';

  @override
  String get discoveryCacheEyebrow => 'LOCAL CRYPTOGRAPHIC CACHE';

  @override
  String get discoverySynchronizing => 'SYNCHRONIZING...';

  @override
  String discoveryPassesReady(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count PASSES READY',
      one: '1 PASS READY',
    );
    return '$_temp0';
  }

  @override
  String get discoveryOfflineBanner => 'Offline — showing cached events';

  @override
  String discoveryLastSynchronized(String duration) {
    return 'Last synchronized $duration ago';
  }

  @override
  String get discoveryReconnect => 'Reconnect';

  @override
  String get discoverySearchHint => 'Search events, venues, cities';

  @override
  String get discoverySearchClear => 'Clear search';

  @override
  String get discoveryPriceFrom => 'FROM';

  @override
  String discoveryPrice(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String get discoverySoldOut => 'SOLD OUT';

  @override
  String get discoveryCachedTag => 'CACHED';

  @override
  String get discoveryEmptyTitle => 'No events found';

  @override
  String get discoveryEmptyMessage =>
      'Nothing matches your search right now. Try a different term.';

  @override
  String get discoveryEmptyFeedMessage =>
      'There are no events on sale at the moment. Check back soon.';

  @override
  String discoveryVenueSeparator(String venue, String city) {
    return '$venue • $city';
  }

  @override
  String discoveryEventCardLabel(String title, String date, String price) {
    return '$title, $date, from $price';
  }

  @override
  String durationMinutes(int minutes) {
    return '${minutes}m';
  }

  @override
  String durationHours(int hours) {
    return '${hours}h';
  }

  @override
  String durationDays(int days) {
    return '${days}d';
  }

  @override
  String get detailOfficialGateEntry => 'OFFICIAL GATE ENTRY';

  @override
  String get detailDateTimeLabel => 'DATE & TIME';

  @override
  String get detailLocationLabel => 'LOCATION';

  @override
  String get detailOverviewLabel => 'OVERVIEW';

  @override
  String detailGatesAt(String time, String zone, String doors) {
    return '$time $zone (Gates $doors)';
  }

  @override
  String detailTimeNoGates(String time, String zone) {
    return '$time $zone';
  }

  @override
  String get detailStartingFrom => 'STARTING FROM';

  @override
  String get detailFeesIncluded => 'VAT & Gate Fees Included';

  @override
  String get detailSelectSeats => 'Select seats';

  @override
  String get detailSoldOut => 'Sold out';

  @override
  String get detailNotOnSale => 'Not yet on sale';

  @override
  String get detailAntiPassback => 'Anti-passback enabled';

  @override
  String get detailShare => 'Share event';

  @override
  String get detailBack => 'Back';

  @override
  String get detailMissingTitle => 'Event not available';

  @override
  String get detailMissingMessage =>
      'This event may have ended or the link may be out of date.';

  @override
  String get detailBrowseEvents => 'Browse events';

  @override
  String get detailSeatSelectionSoon =>
      'Seat selection opens in the next release.';

  @override
  String get detailShareSoon => 'Sharing opens in the next release.';

  @override
  String get errorLocked => 'This section is not available for booking.';

  @override
  String get seatLegendAvailable => 'Available';

  @override
  String get seatLegendTaken => 'Taken';

  @override
  String get seatLegendConflict => 'Conflict (409)';

  @override
  String get seatLegendHeld => 'Held (You)';

  @override
  String get seatLegendSold => 'Sold';

  @override
  String get seatStage => 'STAGE / PERFORMANCE';

  @override
  String get seatStagePodium => 'STAGE / MAIN PODIUM';

  @override
  String get seatTakenTag => 'TAKEN';

  @override
  String get seatStatusLive => 'Live Sync';

  @override
  String get seatStatusLabel => 'STATUS';

  @override
  String get seatCurrentSelection => 'CURRENT SELECTION';

  @override
  String get seatNoSelection => 'No seat selected';

  @override
  String get seatSubtotal => 'SUBTOTAL';

  @override
  String get seatSelectPrompt => 'Select an available seat';

  @override
  String get seatHoldSeat => 'Hold seat';

  @override
  String get seatConflictEyebrow => 'CONFLICT · HTTP 409';

  @override
  String get seatConflictTitle => 'Seat just taken — pick another';

  @override
  String get seatConflictMessage =>
      'Another guest completed reservation for this seat milliseconds ago. Your selection has been cleared.';

  @override
  String seatConflictSeat(String seat) {
    return 'Seat $seat';
  }

  @override
  String get seatLockedStatus => 'HTTP 423 · LOCKED';

  @override
  String get seatLockedTitle => 'Sector locked by organizer';

  @override
  String seatLockedMessage(String sector) {
    return '$sector is currently held for production allocation or artist delegation. Individual seats cannot be reserved.';
  }

  @override
  String get seatLockedTargetLabel => 'Target Sector';

  @override
  String get seatLockedReasonLabel => 'Lock Reason';

  @override
  String get seatLockedAlternativesLabel => 'Available Alternatives';

  @override
  String get seatChooseAnotherSector => 'Choose another sector';

  @override
  String get seatViewAvailableOnly => 'View available sectors only';

  @override
  String seatHeldBadge(String reference) {
    return 'HELD ($reference)';
  }

  @override
  String get seatSeatsHeld => 'SEATS HELD';

  @override
  String get seatLockedToOrder => 'LOCKED TO ORDER';

  @override
  String get seatSelectionLockedNote =>
      'Seat selection locked while timer is running';

  @override
  String get seatAssignedSelection => 'ASSIGNED SELECTION';

  @override
  String get seatTotalPrice => 'Total Price';

  @override
  String get seatFeesNote => 'Incl. VAT & Gate Access';

  @override
  String get seatContinueCheckout => 'Continue to checkout';

  @override
  String seatRowSeatCaption(String row, String seat) {
    return '(Row $row, Seat $seat)';
  }

  @override
  String get seatUnavailableInTier => 'UNAVAILABLE IN THIS TIER';

  @override
  String get seatHoldExpiredTitle => 'Hold expired';

  @override
  String get seatHoldExpiredMessage =>
      'Your seats were released. Choose again to continue.';

  @override
  String get seatChooseAgain => 'Choose again';

  @override
  String get seatDismiss => 'Dismiss';

  @override
  String get checkoutTitle => 'Order Checkout';

  @override
  String get checkoutWindowActive => 'PAYMENT WINDOW ACTIVE';

  @override
  String checkoutWindowExtended(int minutes) {
    return 'Hold extended +${minutes}m for checkout';
  }

  @override
  String get checkoutConfirmedReservation => 'CONFIRMED RESERVATION';

  @override
  String get checkoutSeatReserved => 'SEAT RESERVED';

  @override
  String get checkoutPriceBreakdown => 'PRICE BREAKDOWN';

  @override
  String checkoutVatRegistration(String number) {
    return 'VAT Reg #$number';
  }

  @override
  String get checkoutTotalAmount => 'Total Amount';

  @override
  String checkoutPayNow(String amount, String currency) {
    return 'Pay now · $amount $currency';
  }

  @override
  String get checkoutCancelHold => 'Cancel hold';

  @override
  String get checkoutCancelTitle => 'Release your seats?';

  @override
  String get checkoutCancelMessage =>
      'Your reserved seats will be returned to public inventory and may be taken by someone else.';

  @override
  String get checkoutCancelConfirm => 'Release seats';

  @override
  String get checkoutKeepHold => 'Keep my seats';

  @override
  String get checkoutSessionTimeout => 'SESSION TIMEOUT';

  @override
  String get checkoutHoldTimer => 'HOLD TIMER';

  @override
  String get checkoutExpiredTitle => 'Hold expired —';

  @override
  String get checkoutExpiredTitleAccent => 'seats released';

  @override
  String get checkoutExpiredMessage =>
      'Your temporary reservation window reached zero. To ensure fair access across high-demand events, previously reserved seats have been returned to public inventory.';

  @override
  String get checkoutReleasedReservation => 'RELEASED RESERVATION';

  @override
  String get checkoutExpiredTag => 'EXPIRED';

  @override
  String checkoutHeldSeat(String seat) {
    return 'Held Seat: $seat';
  }

  @override
  String checkoutPolicyNote(String code) {
    return '$code: Strict TTL seat lifecycle policy';
  }

  @override
  String get checkoutSelectSeatsAgain => 'SELECT SEATS AGAIN';

  @override
  String get checkoutReturnToEvent => 'Return to Event Overview';

  @override
  String get checkoutPaymentUnavailable =>
      'Payment could not be started. Please try again.';

  @override
  String get checkoutGatewayOpens => 'Opening secure payment…';

  @override
  String get passActiveBadge => 'ACTIVE GATE PASS';

  @override
  String passReferenceLine(String reference) {
    return '$reference · TOTP';
  }

  @override
  String get passSeatLabel => 'SEAT';

  @override
  String get passHighLuminosity => 'Screen set to high luminosity';

  @override
  String get passCardBrand => 'TAZKERAH';

  @override
  String get passDynamicPass => 'DYNAMIC PASS';

  @override
  String passSecondsRemaining(int seconds) {
    return '${seconds}s';
  }

  @override
  String get passRemainingSuffix => 'remaining';

  @override
  String passRefreshNote(int seconds) {
    return 'Code refreshes every ${seconds}s';
  }

  @override
  String get passSecurityNote =>
      'ANTI-SCREENSHOT WATERMARKED · SINGLE ENTRY ONLY';

  @override
  String get passHolder => 'Holder';

  @override
  String get passEntrance => 'Entrance';

  @override
  String get passStatusRow => 'Status';

  @override
  String passFastTrack(String gate) {
    return '$gate · FastTrack';
  }

  @override
  String get passOnlineValidated => 'Online Validated';

  @override
  String get passScannerHint => 'Hold phone directly over scanner glass';

  @override
  String get passClockStale =>
      'Device clock is out of sync. The gate may reject this code.';

  @override
  String get passInterceptEyebrow => 'SECURITY INTERCEPT';

  @override
  String get passInterceptJustNow => 'JUST NOW';

  @override
  String get passInterceptTitle =>
      'Screenshot detected: Code refreshed for security.';

  @override
  String get passInterceptMessage =>
      'Static copies are invalid at the gate. Tap to reveal a fresh code.';

  @override
  String get passRedacted => 'PAYLOAD REDACTED';

  @override
  String passRedactedHash(String hash) {
    return 'HASH: $hash';
  }

  @override
  String get passAntiScreenshotGuard => 'ANTI-SCREENSHOT GUARD';

  @override
  String get passRekeying => 'RE-KEYING SEED:';

  @override
  String get passNewTokenReady => 'NEW TOKEN READY';

  @override
  String passRollingNote(int seconds) {
    return 'Dynamic rolling ticket · STRICT ${seconds}s TOTP cycle';
  }

  @override
  String get passVenueEntry => 'VENUE ENTRY';

  @override
  String get passValidation => 'VALIDATION';

  @override
  String get passSynced => 'SYNCED';

  @override
  String get passDeviceId => 'DEVICE ID';

  @override
  String get passRevealFresh => 'Reveal fresh dynamic QR';

  @override
  String get passSecuredBy =>
      'Secured by Tazkerah Anti-Passback & In-Memory TOTP Protocol';

  @override
  String get passConfirmedAccess => 'CONFIRMED ACCESS · SECURE TOTP PASS';

  @override
  String passZoneSeat(String zone, String seat) {
    return 'ZONE: $zone · SEAT: $seat';
  }

  @override
  String get passUnavailableTitle => 'Pass not available';

  @override
  String get passUnavailableConsumed =>
      'This pass has already been used. Single entry only.';

  @override
  String get passUnavailableInvalid => 'This pass is no longer valid.';

  @override
  String passSkewBadge(int seconds) {
    return 'SKEW > ${seconds}s';
  }

  @override
  String passAuthProtocol(String reference) {
    return '$reference · Gate Auth Protocol';
  }

  @override
  String get passSkewTitle => 'DEVICE TIME OUT OF SYNC';

  @override
  String passSkewMessage(int seconds, String policy) {
    return 'Clock drift exceeded $seconds seconds. Dynamic TOTP QR code hidden for access integrity per security policy $policy.';
  }

  @override
  String get passHolderLabel => 'PASS HOLDER';

  @override
  String get passAssignedSeat => 'ASSIGNED SEAT';

  @override
  String passQrSuppressed(String policy) {
    return 'QR DISPLAY SUPPRESSED ($policy)';
  }

  @override
  String get passManualCodeLabel => 'MANUAL ENTRY FALLBACK CODE';

  @override
  String get passManualCodeHelp =>
      'Present this 8-digit emergency code directly to the steward at the gate terminal for manual validation.';

  @override
  String passOffsetReadout(String offset) {
    return 'Offset: $offset Skew';
  }

  @override
  String passHashReadout(String hash) {
    return 'Hash: $hash';
  }

  @override
  String get passResyncAction => 'Attempt Time Re-sync (NTP)';

  @override
  String get passStaffOverride =>
      'Gate staff can override via offline keypad entry';

  @override
  String get passResyncFailed =>
      'Could not reach the time server. The fallback code is still valid.';

  @override
  String get passResyncStillSkewed =>
      'Clock is still out of sync. Keep using the fallback code.';

  @override
  String get walletTitle => 'My Tickets';

  @override
  String get walletUpcoming => 'UPCOMING';

  @override
  String get walletPast => 'PAST';

  @override
  String get walletEmptyTitle => 'No tickets yet';

  @override
  String get walletEmptyMessage =>
      'Tickets you buy will appear here, ready to present at the gate.';

  @override
  String get walletBrowseEvents => 'Browse events';

  @override
  String get walletStatusValid => 'VALID';

  @override
  String get walletStatusUsed => 'USED';

  @override
  String get walletStatusRefunded => 'REFUNDED';

  @override
  String get walletStatusExpired => 'EXPIRED';

  @override
  String ticketOrderReference(String reference) {
    return 'ORDER $reference';
  }

  @override
  String get ticketSeatLabel => 'SEAT';

  @override
  String get ticketZoneLabel => 'ZONE';

  @override
  String get ticketGateLabel => 'GATE';

  @override
  String get ticketPaidLabel => 'PAID';

  @override
  String ticketPurchasedOn(String date) {
    return 'Purchased $date';
  }

  @override
  String get ticketPresentAction => 'Present at gate';

  @override
  String get ticketCannotPresent => 'This ticket can no longer be presented.';

  @override
  String get ticketMissingTitle => 'Ticket not found';

  @override
  String get ticketMissingMessage =>
      'This ticket may have been transferred or the link may be out of date.';

  @override
  String get ticketViewEvent => 'View event';

  @override
  String get confirmationSettlingTitle => 'Confirming your payment';

  @override
  String get confirmationSettlingMessage =>
      'This usually takes a few seconds. Do not close the app.';

  @override
  String get confirmationTitle => 'Purchase confirmed';

  @override
  String get confirmationMessage =>
      'Your ticket is ready. Present it at the gate when you arrive.';

  @override
  String get confirmationViewTicket => 'View my ticket';

  @override
  String get confirmationGoToWallet => 'Go to my tickets';

  @override
  String get confirmationPendingTitle => 'Payment is taking longer than usual';

  @override
  String get confirmationPendingMessage =>
      'If the payment succeeded, your ticket will appear in My Tickets shortly. You have not been charged twice.';

  @override
  String get conciergeTitle => 'Concierge';

  @override
  String get conciergeSubtitle => 'Ask about gates, seating and your tickets';

  @override
  String get conciergeEmptyTitle => 'How can I help?';

  @override
  String get conciergeEmptyMessage =>
      'Ask about gate times, where your seat is, or what your ticket covers.';

  @override
  String get conciergeComposerHint => 'Ask a question';

  @override
  String get conciergeSend => 'Send';

  @override
  String get conciergeThinking => 'Thinking…';

  @override
  String get conciergeInterrupted => 'Answer interrupted';

  @override
  String get conciergeRetry => 'Try again';

  @override
  String get conciergeSources => 'SOURCES';

  @override
  String get conciergeOfflineTitle => 'Concierge needs a connection';

  @override
  String get conciergeOfflineMessage =>
      'Answers are looked up on our servers, so the concierge cannot work offline. Your tickets remain available in My Tickets.';

  @override
  String get conciergeClear => 'Clear conversation';

  @override
  String get conciergeDisclaimer =>
      'Answers may be incomplete. Check your ticket for the final details.';

  @override
  String get conciergeSuggestionGates => 'When do gates open?';

  @override
  String get conciergeSuggestionSeat => 'Where is my seat?';

  @override
  String get conciergeSuggestionRefund => 'What is the refund policy?';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileAccountSection => 'ACCOUNT';

  @override
  String get profileSecuritySection => 'SECURITY';

  @override
  String get profileAppSection => 'APP';

  @override
  String get profileEmailLabel => 'Email';

  @override
  String get profilePhoneLabel => 'Phone';

  @override
  String profileMemberSince(String date) {
    return 'Member since $date';
  }

  @override
  String get profileDeviceLabel => 'This device';

  @override
  String get profileDeviceNote =>
      'Your passes are bound to this device and cannot be presented from another.';

  @override
  String get profileLanguageLabel => 'Language';

  @override
  String get profileLanguageSystem => 'System default';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileSignOutTitle => 'Sign out of Tazkerah?';

  @override
  String get profileSignOutMessage =>
      'Your tickets stay on your account, but this device will no longer be able to present them until you sign in again.';

  @override
  String get profileSignOutConfirm => 'Sign out';

  @override
  String get profileStay => 'Stay signed in';

  @override
  String profileVersion(String version, String build) {
    return 'Version $version ($build)';
  }
}
