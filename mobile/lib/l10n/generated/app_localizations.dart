import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// Application name, shown in the task switcher and app bar.
  ///
  /// In en, this message translates to:
  /// **'Tazkerah'**
  String get appTitle;

  /// Label for the button that re-runs a failed operation.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Label for the button that dismisses an action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Label for the button that acknowledges a message.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// Shown when the device cannot reach the server at all.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Check your network and try again.'**
  String get errorNetwork;

  /// Shown when a request exceeds its time budget.
  ///
  /// In en, this message translates to:
  /// **'The request took too long. Please try again.'**
  String get errorTimeout;

  /// Shown for HTTP 5xx responses.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong on our end. Please try again shortly.'**
  String get errorServer;

  /// Shown when authentication is missing, invalid, or expired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errorUnauthorized;

  /// Fallback for errors with no more specific message.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get errorUnexpected;

  /// Heading for a screen with no content to display.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get stateEmptyTitle;

  /// Banner shown when the app is serving cached content.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Showing saved data.'**
  String get stateOfflineBanner;

  /// Row label for choosing the app language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Theme option that follows the OS light/dark setting.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsThemeSystem;

  /// Theme option forcing the light palette.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// Theme option forcing the dark palette.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// The Latin wordmark. Stays Latin in every locale — it is half of the logo lockup, paired with the Arabic form, not translated copy.
  ///
  /// In en, this message translates to:
  /// **'Tazkerah'**
  String get appTitleLatin;

  /// The Arabic wordmark shown beside the Latin 'Tazkerah' on the auth screen. Stays Arabic in every locale — it is part of the logo lockup, not translated copy.
  ///
  /// In en, this message translates to:
  /// **'تذكرة'**
  String get authBrandNameArabic;

  /// Subtitle under the brand name on the sign-in screen.
  ///
  /// In en, this message translates to:
  /// **'Access your secure digital passes and encrypted gate entry.'**
  String get authTagline;

  /// Uppercase field label above the sign-in input.
  ///
  /// In en, this message translates to:
  /// **'EMAIL OR PHONE'**
  String get authIdentifierLabel;

  /// Placeholder inside the email-or-phone field.
  ///
  /// In en, this message translates to:
  /// **'name@domain.com or +966...'**
  String get authIdentifierHint;

  /// Primary button that submits the email or phone number.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get authContinue;

  /// Inline badge under the tagline when the device has no connection.
  ///
  /// In en, this message translates to:
  /// **'Offline — Network connection required'**
  String get authOfflineBadge;

  /// Paragraph explaining why sign-in is unavailable offline.
  ///
  /// In en, this message translates to:
  /// **'Network unavailable. An active internet connection is required to authenticate your identity and issue encrypted gate passes.'**
  String get authOfflineExplanation;

  /// Link that retries the connectivity check.
  ///
  /// In en, this message translates to:
  /// **'Check connection'**
  String get authCheckConnection;

  /// Validation message when the sign-in field is left empty.
  ///
  /// In en, this message translates to:
  /// **'Enter your email or phone number.'**
  String get authIdentifierRequired;

  /// Validation message when the entered identifier is neither a valid email nor a valid phone number.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address or phone number.'**
  String get authIdentifierInvalid;

  /// Footer link to the terms of service.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get legalTerms;

  /// Footer link to the privacy policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get legalPrivacy;

  /// Uppercase mono label above the event list heading. Passed through as written, so translations supply their own casing.
  ///
  /// In en, this message translates to:
  /// **'EXCLUSIVE GATE ENTRIES'**
  String get eventsEyebrow;

  /// Status pill beside the event list heading, shown when the feed is live.
  ///
  /// In en, this message translates to:
  /// **'LIVE PASSES'**
  String get eventsLivePasses;

  /// Bottom navigation label for the event discovery tab.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get navEvents;

  /// Bottom navigation label for the user's ticket wallet tab.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get navTickets;

  /// Bottom navigation label for the AI assistant tab.
  ///
  /// In en, this message translates to:
  /// **'Concierge'**
  String get navConcierge;

  /// Bottom navigation label for the account tab.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Title shown when a deep link points at an unknown route.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get routeNotFoundTitle;

  /// Body text shown when a deep link points at an unknown route.
  ///
  /// In en, this message translates to:
  /// **'The link you followed does not lead anywhere.'**
  String get routeNotFoundMessage;

  /// Button that returns the user to the home screen.
  ///
  /// In en, this message translates to:
  /// **'Go to home'**
  String get routeGoHome;

  /// Screen heading for the code verification step.
  ///
  /// In en, this message translates to:
  /// **'Security code'**
  String get otpTitle;

  /// Uppercase label above the six code boxes.
  ///
  /// In en, this message translates to:
  /// **'SECURITY CODE'**
  String get otpCodeLabel;

  /// Hint at the end of the code label row, stating the expected length.
  ///
  /// In en, this message translates to:
  /// **'6 digits'**
  String get otpDigitsHint;

  /// Link that returns to the previous step to change the email or phone.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get otpEdit;

  /// Prompt beside the resend link.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive code?'**
  String get otpNoCode;

  /// Link that requests a new verification code.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get otpResend;

  /// Replaces the resend link while a cooldown is running. {seconds} is the remaining whole seconds.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String otpResendIn(int seconds);

  /// Primary button that submits the entered code.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// Inline error under the code boxes when the server rejects the code.
  ///
  /// In en, this message translates to:
  /// **'Invalid code. Try again.'**
  String get otpInvalid;

  /// Inline error when the code is past its validity window.
  ///
  /// In en, this message translates to:
  /// **'That code expired. Request a new one.'**
  String get otpExpired;

  /// Inline error when the server rate-limits verification.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later.'**
  String get otpTooManyAttempts;

  /// Confirmation shown after a successful resend.
  ///
  /// In en, this message translates to:
  /// **'A new code is on its way.'**
  String get otpResent;

  /// Main heading of the event discovery screen.
  ///
  /// In en, this message translates to:
  /// **'Select Experience'**
  String get discoveryTitle;

  /// Uppercase mono label above the heading when the feed is showing cached data. Passed through as written, so translations supply their own casing.
  ///
  /// In en, this message translates to:
  /// **'LOCAL CRYPTOGRAPHIC CACHE'**
  String get discoveryCacheEyebrow;

  /// Status pill beside the heading while the first page is loading.
  ///
  /// In en, this message translates to:
  /// **'SYNCHRONIZING...'**
  String get discoverySynchronizing;

  /// Status pill beside the heading in the offline state, counting the cached events available.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 PASS READY} other{{count} PASSES READY}}'**
  String discoveryPassesReady(int count);

  /// Amber banner across the top of the feed when the rows come from the local cache.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing cached events'**
  String get discoveryOfflineBanner;

  /// Footer note in the offline state. {duration} is an already-formatted span such as '14m' or '2h'.
  ///
  /// In en, this message translates to:
  /// **'Last synchronized {duration} ago'**
  String discoveryLastSynchronized(String duration);

  /// Footer button that retries the connection from the offline state.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get discoveryReconnect;

  /// Placeholder inside the discovery search field.
  ///
  /// In en, this message translates to:
  /// **'Search events, venues, cities'**
  String get discoverySearchHint;

  /// Accessibility label for the button that empties the search field.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get discoverySearchClear;

  /// Uppercase mono label above a card's starting price.
  ///
  /// In en, this message translates to:
  /// **'FROM'**
  String get discoveryPriceFrom;

  /// A card's starting price. {amount} is already formatted for the locale; {currency} is an ISO code such as SAR.
  ///
  /// In en, this message translates to:
  /// **'{amount} {currency}'**
  String discoveryPrice(String amount, String currency);

  /// Tag on a card whose tickets are all gone.
  ///
  /// In en, this message translates to:
  /// **'SOLD OUT'**
  String get discoverySoldOut;

  /// Tag on a card served from the local cache.
  ///
  /// In en, this message translates to:
  /// **'CACHED'**
  String get discoveryCachedTag;

  /// Heading when the feed returns no rows.
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get discoveryEmptyTitle;

  /// Body text when a search returns no rows.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches your search right now. Try a different term.'**
  String get discoveryEmptyMessage;

  /// Body text when the unfiltered feed returns no rows.
  ///
  /// In en, this message translates to:
  /// **'There are no events on sale at the moment. Check back soon.'**
  String get discoveryEmptyFeedMessage;

  /// A card's location line, joining the venue and its city.
  ///
  /// In en, this message translates to:
  /// **'{venue} • {city}'**
  String discoveryVenueSeparator(String venue, String city);

  /// Accessibility label read for one event card.
  ///
  /// In en, this message translates to:
  /// **'{title}, {date}, from {price}'**
  String discoveryEventCardLabel(String title, String date, String price);

  /// A short span in minutes, for the offline footer.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String durationMinutes(int minutes);

  /// A short span in hours, for the offline footer.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String durationHours(int hours);

  /// A short span in days, for the offline footer.
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String durationDays(int days);

  /// Pill over the event hero image, marking the listing as an authorised seller.
  ///
  /// In en, this message translates to:
  /// **'OFFICIAL GATE ENTRY'**
  String get detailOfficialGateEntry;

  /// Uppercase label on the date card.
  ///
  /// In en, this message translates to:
  /// **'DATE & TIME'**
  String get detailDateTimeLabel;

  /// Uppercase label on the location card.
  ///
  /// In en, this message translates to:
  /// **'LOCATION'**
  String get detailLocationLabel;

  /// Uppercase heading above the event description.
  ///
  /// In en, this message translates to:
  /// **'OVERVIEW'**
  String get detailOverviewLabel;

  /// The event time line. {time} and {doors} are formatted clock times; {zone} is a timezone abbreviation such as AST.
  ///
  /// In en, this message translates to:
  /// **'{time} {zone} (Gates {doors})'**
  String detailGatesAt(String time, String zone, String doors);

  /// The event time line when no separate gates time is published.
  ///
  /// In en, this message translates to:
  /// **'{time} {zone}'**
  String detailTimeNoGates(String time, String zone);

  /// Label above the price in the bottom action bar.
  ///
  /// In en, this message translates to:
  /// **'STARTING FROM'**
  String get detailStartingFrom;

  /// Note under the price in the bottom action bar.
  ///
  /// In en, this message translates to:
  /// **'VAT & Gate Fees Included'**
  String get detailFeesIncluded;

  /// Primary button that opens seat selection.
  ///
  /// In en, this message translates to:
  /// **'Select seats'**
  String get detailSelectSeats;

  /// Replaces the seat-selection button when no tickets remain.
  ///
  /// In en, this message translates to:
  /// **'Sold out'**
  String get detailSoldOut;

  /// Replaces the seat-selection button before tickets are released.
  ///
  /// In en, this message translates to:
  /// **'Not yet on sale'**
  String get detailNotOnSale;

  /// Note beside the ticket security row, stating the pass cannot be re-used for re-entry by another person.
  ///
  /// In en, this message translates to:
  /// **'Anti-passback enabled'**
  String get detailAntiPassback;

  /// Accessibility label for the share button over the hero image.
  ///
  /// In en, this message translates to:
  /// **'Share event'**
  String get detailShare;

  /// Accessibility label for the back button over the hero image.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get detailBack;

  /// Heading shown when the requested event does not exist.
  ///
  /// In en, this message translates to:
  /// **'Event not available'**
  String get detailMissingTitle;

  /// Body text shown when the requested event does not exist.
  ///
  /// In en, this message translates to:
  /// **'This event may have ended or the link may be out of date.'**
  String get detailMissingMessage;

  /// Button returning the user to the event feed from a missing event.
  ///
  /// In en, this message translates to:
  /// **'Browse events'**
  String get detailBrowseEvents;

  /// Temporary notice shown when seat selection is tapped, before the booking flow exists.
  ///
  /// In en, this message translates to:
  /// **'Seat selection opens in the next release.'**
  String get detailSeatSelectionSoon;

  /// Temporary notice shown when the share button is tapped, before platform sharing is wired up.
  ///
  /// In en, this message translates to:
  /// **'Sharing opens in the next release.'**
  String get detailShareSoon;

  /// Shown when the server locks a resource (HTTP 423), such as a sector withheld by the organizer.
  ///
  /// In en, this message translates to:
  /// **'This section is not available for booking.'**
  String get errorLocked;

  /// Seat map legend entry for a seat that can be chosen.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get seatLegendAvailable;

  /// Seat map legend entry for a seat someone else holds.
  ///
  /// In en, this message translates to:
  /// **'Taken'**
  String get seatLegendTaken;

  /// Seat map legend entry for the seat that just lost a reservation race.
  ///
  /// In en, this message translates to:
  /// **'Conflict (409)'**
  String get seatLegendConflict;

  /// Seat map legend entry for a seat held by this user.
  ///
  /// In en, this message translates to:
  /// **'Held (You)'**
  String get seatLegendHeld;

  /// Seat map legend entry for a sold seat.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get seatLegendSold;

  /// Label on the stage marker above the seat map.
  ///
  /// In en, this message translates to:
  /// **'STAGE / PERFORMANCE'**
  String get seatStage;

  /// Stage marker label used when the venue has a podium.
  ///
  /// In en, this message translates to:
  /// **'STAGE / MAIN PODIUM'**
  String get seatStagePodium;

  /// Small tag pinned over the seat that was just taken by someone else.
  ///
  /// In en, this message translates to:
  /// **'TAKEN'**
  String get seatTakenTag;

  /// Header status showing the seat map is receiving live availability.
  ///
  /// In en, this message translates to:
  /// **'Live Sync'**
  String get seatStatusLive;

  /// Uppercase label above the seat map's live-sync status.
  ///
  /// In en, this message translates to:
  /// **'STATUS'**
  String get seatStatusLabel;

  /// Label above the currently chosen seat in the bottom bar.
  ///
  /// In en, this message translates to:
  /// **'CURRENT SELECTION'**
  String get seatCurrentSelection;

  /// Shown in the bottom bar when nothing is chosen.
  ///
  /// In en, this message translates to:
  /// **'No seat selected'**
  String get seatNoSelection;

  /// Label above the running total in the seat bottom bar.
  ///
  /// In en, this message translates to:
  /// **'SUBTOTAL'**
  String get seatSubtotal;

  /// Disabled button label prompting the user to choose a seat.
  ///
  /// In en, this message translates to:
  /// **'Select an available seat'**
  String get seatSelectPrompt;

  /// Button that reserves the chosen seat.
  ///
  /// In en, this message translates to:
  /// **'Hold seat'**
  String get seatHoldSeat;

  /// Mono eyebrow on the seat-conflict toast.
  ///
  /// In en, this message translates to:
  /// **'CONFLICT · HTTP 409'**
  String get seatConflictEyebrow;

  /// Headline on the seat-conflict toast.
  ///
  /// In en, this message translates to:
  /// **'Seat just taken — pick another'**
  String get seatConflictTitle;

  /// Body copy on the seat-conflict toast.
  ///
  /// In en, this message translates to:
  /// **'Another guest completed reservation for this seat milliseconds ago. Your selection has been cleared.'**
  String get seatConflictMessage;

  /// Names the seat that was lost, shown on the conflict toast. {seat} is a seat id such as 'VIP · A-12'.
  ///
  /// In en, this message translates to:
  /// **'Seat {seat}'**
  String seatConflictSeat(String seat);

  /// Mono status pill at the top of the locked-sector sheet.
  ///
  /// In en, this message translates to:
  /// **'HTTP 423 · LOCKED'**
  String get seatLockedStatus;

  /// Headline of the locked-sector sheet.
  ///
  /// In en, this message translates to:
  /// **'Sector locked by organizer'**
  String get seatLockedTitle;

  /// Body copy of the locked-sector sheet. {sector} names the locked sector and its rows.
  ///
  /// In en, this message translates to:
  /// **'{sector} is currently held for production allocation or artist delegation. Individual seats cannot be reserved.'**
  String seatLockedMessage(String sector);

  /// Row label in the locked-sector detail table.
  ///
  /// In en, this message translates to:
  /// **'Target Sector'**
  String get seatLockedTargetLabel;

  /// Row label in the locked-sector detail table.
  ///
  /// In en, this message translates to:
  /// **'Lock Reason'**
  String get seatLockedReasonLabel;

  /// Row label listing sectors the user can still book.
  ///
  /// In en, this message translates to:
  /// **'Available Alternatives'**
  String get seatLockedAlternativesLabel;

  /// Primary action on the locked-sector sheet.
  ///
  /// In en, this message translates to:
  /// **'Choose another sector'**
  String get seatChooseAnotherSector;

  /// Secondary action filtering the map to bookable sectors.
  ///
  /// In en, this message translates to:
  /// **'View available sectors only'**
  String get seatViewAvailableOnly;

  /// Header pill confirming a hold, with its booking reference.
  ///
  /// In en, this message translates to:
  /// **'HELD ({reference})'**
  String seatHeldBadge(String reference);

  /// Label above the hold countdown timer.
  ///
  /// In en, this message translates to:
  /// **'SEATS HELD'**
  String get seatSeatsHeld;

  /// Tag on the sector panel showing the held seat belongs to this order.
  ///
  /// In en, this message translates to:
  /// **'LOCKED TO ORDER'**
  String get seatLockedToOrder;

  /// Note explaining why the map is not interactive during a hold.
  ///
  /// In en, this message translates to:
  /// **'Seat selection locked while timer is running'**
  String get seatSelectionLockedNote;

  /// Label above the held seat in the bottom bar.
  ///
  /// In en, this message translates to:
  /// **'ASSIGNED SELECTION'**
  String get seatAssignedSelection;

  /// Label above the total in the held bottom bar.
  ///
  /// In en, this message translates to:
  /// **'Total Price'**
  String get seatTotalPrice;

  /// Note under the total price in the held bottom bar.
  ///
  /// In en, this message translates to:
  /// **'Incl. VAT & Gate Access'**
  String get seatFeesNote;

  /// Primary action once a seat is held.
  ///
  /// In en, this message translates to:
  /// **'Continue to checkout'**
  String get seatContinueCheckout;

  /// Caption spelling out a seat id. Both values are machine identifiers.
  ///
  /// In en, this message translates to:
  /// **'(Row {row}, Seat {seat})'**
  String seatRowSeatCaption(String row, String seat);

  /// Tag on a context sector the current ticket tier cannot book.
  ///
  /// In en, this message translates to:
  /// **'UNAVAILABLE IN THIS TIER'**
  String get seatUnavailableInTier;

  /// Headline when the reservation countdown reaches zero.
  ///
  /// In en, this message translates to:
  /// **'Hold expired'**
  String get seatHoldExpiredTitle;

  /// Body copy when the reservation countdown reaches zero.
  ///
  /// In en, this message translates to:
  /// **'Your seats were released. Choose again to continue.'**
  String get seatHoldExpiredMessage;

  /// Action that restarts seat selection after a hold expires.
  ///
  /// In en, this message translates to:
  /// **'Choose again'**
  String get seatChooseAgain;

  /// Accessibility label for closing a toast or sheet.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get seatDismiss;

  /// Header title of the checkout screen.
  ///
  /// In en, this message translates to:
  /// **'Order Checkout'**
  String get checkoutTitle;

  /// Status label on the countdown bar while payment is possible.
  ///
  /// In en, this message translates to:
  /// **'PAYMENT WINDOW ACTIVE'**
  String get checkoutWindowActive;

  /// Sub-label explaining that the seat hold was extended for payment. {minutes} is the extension granted by the server.
  ///
  /// In en, this message translates to:
  /// **'Hold extended +{minutes}m for checkout'**
  String checkoutWindowExtended(int minutes);

  /// Label above the reserved event in the checkout summary.
  ///
  /// In en, this message translates to:
  /// **'CONFIRMED RESERVATION'**
  String get checkoutConfirmedReservation;

  /// Label on the reserved-seat card.
  ///
  /// In en, this message translates to:
  /// **'SEAT RESERVED'**
  String get checkoutSeatReserved;

  /// Heading above the itemised charges.
  ///
  /// In en, this message translates to:
  /// **'PRICE BREAKDOWN'**
  String get checkoutPriceBreakdown;

  /// The seller's VAT registration, shown beside the price breakdown.
  ///
  /// In en, this message translates to:
  /// **'VAT Reg #{number}'**
  String checkoutVatRegistration(String number);

  /// Label for the amount that will be charged.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get checkoutTotalAmount;

  /// Primary button that hands off to the payment gateway.
  ///
  /// In en, this message translates to:
  /// **'Pay now · {amount} {currency}'**
  String checkoutPayNow(String amount, String currency);

  /// Secondary action that releases the reserved seats.
  ///
  /// In en, this message translates to:
  /// **'Cancel hold'**
  String get checkoutCancelHold;

  /// Title of the dialog confirming a hold cancellation.
  ///
  /// In en, this message translates to:
  /// **'Release your seats?'**
  String get checkoutCancelTitle;

  /// Body of the dialog confirming a hold cancellation.
  ///
  /// In en, this message translates to:
  /// **'Your reserved seats will be returned to public inventory and may be taken by someone else.'**
  String get checkoutCancelMessage;

  /// Confirm button in the cancel-hold dialog.
  ///
  /// In en, this message translates to:
  /// **'Release seats'**
  String get checkoutCancelConfirm;

  /// Dismiss button in the cancel-hold dialog.
  ///
  /// In en, this message translates to:
  /// **'Keep my seats'**
  String get checkoutKeepHold;

  /// Status pill shown when the payment window has closed.
  ///
  /// In en, this message translates to:
  /// **'SESSION TIMEOUT'**
  String get checkoutSessionTimeout;

  /// Label above the expired countdown.
  ///
  /// In en, this message translates to:
  /// **'HOLD TIMER'**
  String get checkoutHoldTimer;

  /// First line of the expired headline.
  ///
  /// In en, this message translates to:
  /// **'Hold expired —'**
  String get checkoutExpiredTitle;

  /// Second line of the expired headline, shown in the alert colour.
  ///
  /// In en, this message translates to:
  /// **'seats released'**
  String get checkoutExpiredTitleAccent;

  /// Explanation shown when the payment window closes.
  ///
  /// In en, this message translates to:
  /// **'Your temporary reservation window reached zero. To ensure fair access across high-demand events, previously reserved seats have been returned to public inventory.'**
  String get checkoutExpiredMessage;

  /// Label above the reservation that was lost.
  ///
  /// In en, this message translates to:
  /// **'RELEASED RESERVATION'**
  String get checkoutReleasedReservation;

  /// Tag marking the released reservation.
  ///
  /// In en, this message translates to:
  /// **'EXPIRED'**
  String get checkoutExpiredTag;

  /// Names the seat that was released. {seat} is a seat reference such as 'VIP · A-12'.
  ///
  /// In en, this message translates to:
  /// **'Held Seat: {seat}'**
  String checkoutHeldSeat(String seat);

  /// Reference to the policy under which seats were released. {code} is a rule identifier.
  ///
  /// In en, this message translates to:
  /// **'{code}: Strict TTL seat lifecycle policy'**
  String checkoutPolicyNote(String code);

  /// Primary action returning the user to seat selection.
  ///
  /// In en, this message translates to:
  /// **'SELECT SEATS AGAIN'**
  String get checkoutSelectSeatsAgain;

  /// Secondary action returning the user to the event detail screen.
  ///
  /// In en, this message translates to:
  /// **'Return to Event Overview'**
  String get checkoutReturnToEvent;

  /// Shown when the gateway handoff fails but the window is still open.
  ///
  /// In en, this message translates to:
  /// **'Payment could not be started. Please try again.'**
  String get checkoutPaymentUnavailable;

  /// Shown while handing off to the hosted payment gateway.
  ///
  /// In en, this message translates to:
  /// **'Opening secure payment…'**
  String get checkoutGatewayOpens;

  /// Status label at the top of a presentable gate pass.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE GATE PASS'**
  String get passActiveBadge;

  /// Rule reference and protocol shown beside the pass status.
  ///
  /// In en, this message translates to:
  /// **'{reference} · TOTP'**
  String passReferenceLine(String reference);

  /// Label above the seat on the pass header.
  ///
  /// In en, this message translates to:
  /// **'SEAT'**
  String get passSeatLabel;

  /// Notice that the screen was brightened so a scanner can read the code.
  ///
  /// In en, this message translates to:
  /// **'Screen set to high luminosity'**
  String get passHighLuminosity;

  /// Brand mark printed inside the QR card.
  ///
  /// In en, this message translates to:
  /// **'TAZKERAH'**
  String get passCardBrand;

  /// Label inside the QR card's bottom edge.
  ///
  /// In en, this message translates to:
  /// **'DYNAMIC PASS'**
  String get passDynamicPass;

  /// Seconds left before the code rotates.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String passSecondsRemaining(int seconds);

  /// Word following the countdown seconds.
  ///
  /// In en, this message translates to:
  /// **'remaining'**
  String get passRemainingSuffix;

  /// Explains the rotation cycle. {seconds} comes from the pass grant.
  ///
  /// In en, this message translates to:
  /// **'Code refreshes every {seconds}s'**
  String passRefreshNote(int seconds);

  /// Security properties printed under the pass.
  ///
  /// In en, this message translates to:
  /// **'ANTI-SCREENSHOT WATERMARKED · SINGLE ENTRY ONLY'**
  String get passSecurityNote;

  /// Row label for the ticket holder's name.
  ///
  /// In en, this message translates to:
  /// **'Holder'**
  String get passHolder;

  /// Row label for the gate to use.
  ///
  /// In en, this message translates to:
  /// **'Entrance'**
  String get passEntrance;

  /// Row label for the validation status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get passStatusRow;

  /// Entrance value when the holder has fast-track access.
  ///
  /// In en, this message translates to:
  /// **'{gate} · FastTrack'**
  String passFastTrack(String gate);

  /// Validation status when the pass was checked against the server.
  ///
  /// In en, this message translates to:
  /// **'Online Validated'**
  String get passOnlineValidated;

  /// Instruction under the pass details.
  ///
  /// In en, this message translates to:
  /// **'Hold phone directly over scanner glass'**
  String get passScannerHint;

  /// Warning shown when the corrected clock is too old to trust.
  ///
  /// In en, this message translates to:
  /// **'Device clock is out of sync. The gate may reject this code.'**
  String get passClockStale;

  /// Eyebrow on the capture-detected banner.
  ///
  /// In en, this message translates to:
  /// **'SECURITY INTERCEPT'**
  String get passInterceptEyebrow;

  /// Timestamp on a capture that just happened.
  ///
  /// In en, this message translates to:
  /// **'JUST NOW'**
  String get passInterceptJustNow;

  /// Headline when a screen capture is detected.
  ///
  /// In en, this message translates to:
  /// **'Screenshot detected: Code refreshed for security.'**
  String get passInterceptTitle;

  /// Explains why the captured code no longer works.
  ///
  /// In en, this message translates to:
  /// **'Static copies are invalid at the gate. Tap to reveal a fresh code.'**
  String get passInterceptMessage;

  /// Shown in place of the QR code when it is withheld.
  ///
  /// In en, this message translates to:
  /// **'PAYLOAD REDACTED'**
  String get passRedacted;

  /// The withheld code's hash. Never the code itself.
  ///
  /// In en, this message translates to:
  /// **'HASH: {hash}'**
  String passRedactedHash(String hash);

  /// Tag on the redacted QR placeholder.
  ///
  /// In en, this message translates to:
  /// **'ANTI-SCREENSHOT GUARD'**
  String get passAntiScreenshotGuard;

  /// Label before the new-token status.
  ///
  /// In en, this message translates to:
  /// **'RE-KEYING SEED:'**
  String get passRekeying;

  /// Status showing a fresh code can be revealed.
  ///
  /// In en, this message translates to:
  /// **'NEW TOKEN READY'**
  String get passNewTokenReady;

  /// Describes the rotation policy under the redacted code.
  ///
  /// In en, this message translates to:
  /// **'Dynamic rolling ticket · STRICT {seconds}s TOTP cycle'**
  String passRollingNote(int seconds);

  /// Column label for the gate on the intercepted frame.
  ///
  /// In en, this message translates to:
  /// **'VENUE ENTRY'**
  String get passVenueEntry;

  /// Column label for validation state.
  ///
  /// In en, this message translates to:
  /// **'VALIDATION'**
  String get passValidation;

  /// Validation value when the device is in sync with the server.
  ///
  /// In en, this message translates to:
  /// **'SYNCED'**
  String get passSynced;

  /// Column label for the bound device identifier.
  ///
  /// In en, this message translates to:
  /// **'DEVICE ID'**
  String get passDeviceId;

  /// Button that requests and shows a new code after an intercept.
  ///
  /// In en, this message translates to:
  /// **'Reveal fresh dynamic QR'**
  String get passRevealFresh;

  /// Footer note on the intercepted frame.
  ///
  /// In en, this message translates to:
  /// **'Secured by Tazkerah Anti-Passback & In-Memory TOTP Protocol'**
  String get passSecuredBy;

  /// Eyebrow above the event name on the intercepted frame.
  ///
  /// In en, this message translates to:
  /// **'CONFIRMED ACCESS · SECURE TOTP PASS'**
  String get passConfirmedAccess;

  /// Zone and seat line on the intercepted frame.
  ///
  /// In en, this message translates to:
  /// **'ZONE: {zone} · SEAT: {seat}'**
  String passZoneSeat(String zone, String seat);

  /// Heading when a pass cannot be presented at all.
  ///
  /// In en, this message translates to:
  /// **'Pass not available'**
  String get passUnavailableTitle;

  /// Shown for a consumed pass.
  ///
  /// In en, this message translates to:
  /// **'This pass has already been used. Single entry only.'**
  String get passUnavailableConsumed;

  /// Shown for a revoked or refunded pass.
  ///
  /// In en, this message translates to:
  /// **'This pass is no longer valid.'**
  String get passUnavailableInvalid;

  /// Header pill when clock drift exceeds the suppression threshold.
  ///
  /// In en, this message translates to:
  /// **'SKEW > {seconds}s'**
  String passSkewBadge(int seconds);

  /// Sub-header naming the security policy in force.
  ///
  /// In en, this message translates to:
  /// **'{reference} · Gate Auth Protocol'**
  String passAuthProtocol(String reference);

  /// Headline of the clock-drift banner.
  ///
  /// In en, this message translates to:
  /// **'DEVICE TIME OUT OF SYNC'**
  String get passSkewTitle;

  /// Explains why the QR is withheld. {seconds} is the threshold; {policy} is the rule reference.
  ///
  /// In en, this message translates to:
  /// **'Clock drift exceeded {seconds} seconds. Dynamic TOTP QR code hidden for access integrity per security policy {policy}.'**
  String passSkewMessage(int seconds, String policy);

  /// Label above the pass holder on the fallback frame.
  ///
  /// In en, this message translates to:
  /// **'PASS HOLDER'**
  String get passHolderLabel;

  /// Label above the seat on the fallback frame.
  ///
  /// In en, this message translates to:
  /// **'ASSIGNED SEAT'**
  String get passAssignedSeat;

  /// Chip replacing the QR when it is withheld for clock drift.
  ///
  /// In en, this message translates to:
  /// **'QR DISPLAY SUPPRESSED ({policy})'**
  String passQrSuppressed(String policy);

  /// Label above the typed gate code.
  ///
  /// In en, this message translates to:
  /// **'MANUAL ENTRY FALLBACK CODE'**
  String get passManualCodeLabel;

  /// Instruction under the manual entry code.
  ///
  /// In en, this message translates to:
  /// **'Present this 8-digit emergency code directly to the steward at the gate terminal for manual validation.'**
  String get passManualCodeHelp;

  /// Shows how far the device clock is from server time.
  ///
  /// In en, this message translates to:
  /// **'Offset: {offset} Skew'**
  String passOffsetReadout(String offset);

  /// Shows the code's identifying hash.
  ///
  /// In en, this message translates to:
  /// **'Hash: {hash}'**
  String passHashReadout(String hash);

  /// Button that re-learns the clock offset from the server.
  ///
  /// In en, this message translates to:
  /// **'Attempt Time Re-sync (NTP)'**
  String get passResyncAction;

  /// Footer note on the fallback frame.
  ///
  /// In en, this message translates to:
  /// **'Gate staff can override via offline keypad entry'**
  String get passStaffOverride;

  /// Shown when a re-sync attempt fails.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the time server. The fallback code is still valid.'**
  String get passResyncFailed;

  /// Shown when a re-sync succeeds but drift remains too large.
  ///
  /// In en, this message translates to:
  /// **'Clock is still out of sync. Keep using the fallback code.'**
  String get passResyncStillSkewed;

  /// Title of the ticket wallet screen.
  ///
  /// In en, this message translates to:
  /// **'My Tickets'**
  String get walletTitle;

  /// Section heading for tickets to events still to come.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get walletUpcoming;

  /// Section heading for used, expired and refunded tickets.
  ///
  /// In en, this message translates to:
  /// **'PAST'**
  String get walletPast;

  /// Heading when the wallet holds nothing.
  ///
  /// In en, this message translates to:
  /// **'No tickets yet'**
  String get walletEmptyTitle;

  /// Body text when the wallet holds nothing.
  ///
  /// In en, this message translates to:
  /// **'Tickets you buy will appear here, ready to present at the gate.'**
  String get walletEmptyMessage;

  /// Action taking an empty wallet to the event feed.
  ///
  /// In en, this message translates to:
  /// **'Browse events'**
  String get walletBrowseEvents;

  /// Status tag on a usable ticket.
  ///
  /// In en, this message translates to:
  /// **'VALID'**
  String get walletStatusValid;

  /// Status tag on a ticket already scanned at a gate.
  ///
  /// In en, this message translates to:
  /// **'USED'**
  String get walletStatusUsed;

  /// Status tag on a refunded ticket.
  ///
  /// In en, this message translates to:
  /// **'REFUNDED'**
  String get walletStatusRefunded;

  /// Status tag on a ticket whose event has passed unused.
  ///
  /// In en, this message translates to:
  /// **'EXPIRED'**
  String get walletStatusExpired;

  /// The order a ticket came from.
  ///
  /// In en, this message translates to:
  /// **'ORDER {reference}'**
  String ticketOrderReference(String reference);

  /// Label above the seat on a ticket.
  ///
  /// In en, this message translates to:
  /// **'SEAT'**
  String get ticketSeatLabel;

  /// Label above the zone on a ticket.
  ///
  /// In en, this message translates to:
  /// **'ZONE'**
  String get ticketZoneLabel;

  /// Label above the entrance on a ticket.
  ///
  /// In en, this message translates to:
  /// **'GATE'**
  String get ticketGateLabel;

  /// Label above the amount paid.
  ///
  /// In en, this message translates to:
  /// **'PAID'**
  String get ticketPaidLabel;

  /// When the ticket was bought.
  ///
  /// In en, this message translates to:
  /// **'Purchased {date}'**
  String ticketPurchasedOn(String date);

  /// Primary action opening the rotating gate pass.
  ///
  /// In en, this message translates to:
  /// **'Present at gate'**
  String get ticketPresentAction;

  /// Shown in place of the present action for a used or refunded ticket.
  ///
  /// In en, this message translates to:
  /// **'This ticket can no longer be presented.'**
  String get ticketCannotPresent;

  /// Heading when a ticket id does not exist.
  ///
  /// In en, this message translates to:
  /// **'Ticket not found'**
  String get ticketMissingTitle;

  /// Body text when a ticket id does not exist.
  ///
  /// In en, this message translates to:
  /// **'This ticket may have been transferred or the link may be out of date.'**
  String get ticketMissingMessage;

  /// Action opening the event this ticket belongs to.
  ///
  /// In en, this message translates to:
  /// **'View event'**
  String get ticketViewEvent;

  /// Heading while waiting for the gateway to settle.
  ///
  /// In en, this message translates to:
  /// **'Confirming your payment'**
  String get confirmationSettlingTitle;

  /// Body text while waiting for the gateway to settle.
  ///
  /// In en, this message translates to:
  /// **'This usually takes a few seconds. Do not close the app.'**
  String get confirmationSettlingMessage;

  /// Heading once the ticket has been issued.
  ///
  /// In en, this message translates to:
  /// **'Purchase confirmed'**
  String get confirmationTitle;

  /// Body text once the ticket has been issued.
  ///
  /// In en, this message translates to:
  /// **'Your ticket is ready. Present it at the gate when you arrive.'**
  String get confirmationMessage;

  /// Primary action opening the newly issued ticket.
  ///
  /// In en, this message translates to:
  /// **'View my ticket'**
  String get confirmationViewTicket;

  /// Secondary action opening the wallet.
  ///
  /// In en, this message translates to:
  /// **'Go to my tickets'**
  String get confirmationGoToWallet;

  /// Heading when settlement exceeds the polling window.
  ///
  /// In en, this message translates to:
  /// **'Payment is taking longer than usual'**
  String get confirmationPendingTitle;

  /// Body text when settlement exceeds the polling window.
  ///
  /// In en, this message translates to:
  /// **'If the payment succeeded, your ticket will appear in My Tickets shortly. You have not been charged twice.'**
  String get confirmationPendingMessage;

  /// Title of the AI concierge screen.
  ///
  /// In en, this message translates to:
  /// **'Concierge'**
  String get conciergeTitle;

  /// Sub-heading describing what the concierge can help with.
  ///
  /// In en, this message translates to:
  /// **'Ask about gates, seating and your tickets'**
  String get conciergeSubtitle;

  /// Heading on the empty conversation.
  ///
  /// In en, this message translates to:
  /// **'How can I help?'**
  String get conciergeEmptyTitle;

  /// Body text on the empty conversation.
  ///
  /// In en, this message translates to:
  /// **'Ask about gate times, where your seat is, or what your ticket covers.'**
  String get conciergeEmptyMessage;

  /// Placeholder in the message composer.
  ///
  /// In en, this message translates to:
  /// **'Ask a question'**
  String get conciergeComposerHint;

  /// Accessibility label for the send button.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get conciergeSend;

  /// Shown while waiting for the first token of an answer.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get conciergeThinking;

  /// Tag on an answer whose stream dropped partway.
  ///
  /// In en, this message translates to:
  /// **'Answer interrupted'**
  String get conciergeInterrupted;

  /// Action that re-asks the last question.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get conciergeRetry;

  /// Label above the citations under an answer.
  ///
  /// In en, this message translates to:
  /// **'SOURCES'**
  String get conciergeSources;

  /// Heading when the device is offline.
  ///
  /// In en, this message translates to:
  /// **'Concierge needs a connection'**
  String get conciergeOfflineTitle;

  /// Explains why the concierge is disabled offline, and what still works.
  ///
  /// In en, this message translates to:
  /// **'Answers are looked up on our servers, so the concierge cannot work offline. Your tickets remain available in My Tickets.'**
  String get conciergeOfflineMessage;

  /// Action that empties the conversation.
  ///
  /// In en, this message translates to:
  /// **'Clear conversation'**
  String get conciergeClear;

  /// Standing note under the composer.
  ///
  /// In en, this message translates to:
  /// **'Answers may be incomplete. Check your ticket for the final details.'**
  String get conciergeDisclaimer;

  /// A suggested question on the empty conversation.
  ///
  /// In en, this message translates to:
  /// **'When do gates open?'**
  String get conciergeSuggestionGates;

  /// A suggested question on the empty conversation.
  ///
  /// In en, this message translates to:
  /// **'Where is my seat?'**
  String get conciergeSuggestionSeat;

  /// A suggested question on the empty conversation.
  ///
  /// In en, this message translates to:
  /// **'What is the refund policy?'**
  String get conciergeSuggestionRefund;

  /// Title of the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// Section heading for account details.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get profileAccountSection;

  /// Section heading for device and key details.
  ///
  /// In en, this message translates to:
  /// **'SECURITY'**
  String get profileSecuritySection;

  /// Section heading for app-level settings.
  ///
  /// In en, this message translates to:
  /// **'APP'**
  String get profileAppSection;

  /// Row label for the account email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmailLabel;

  /// Row label for the account phone number.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profilePhoneLabel;

  /// How long the account has existed.
  ///
  /// In en, this message translates to:
  /// **'Member since {date}'**
  String profileMemberSince(String date);

  /// Row label for the bound device identifier.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get profileDeviceLabel;

  /// Explains what device binding means for the user.
  ///
  /// In en, this message translates to:
  /// **'Your passes are bound to this device and cannot be presented from another.'**
  String get profileDeviceNote;

  /// Row label for the app language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profileLanguageLabel;

  /// Language option that follows the device setting.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get profileLanguageSystem;

  /// Action that ends the session on this device.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileSignOut;

  /// Title of the sign-out confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Sign out of Tazkerah?'**
  String get profileSignOutTitle;

  /// Body of the sign-out confirmation dialog.
  ///
  /// In en, this message translates to:
  /// **'Your tickets stay on your account, but this device will no longer be able to present them until you sign in again.'**
  String get profileSignOutMessage;

  /// Confirm button in the sign-out dialog.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get profileSignOutConfirm;

  /// Dismiss button in the sign-out dialog.
  ///
  /// In en, this message translates to:
  /// **'Stay signed in'**
  String get profileStay;

  /// The app version and build number, shown at the foot of the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Version {version} ({build})'**
  String profileVersion(String version, String build);
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
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
