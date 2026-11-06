import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

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
/// import 'gen/app_localizations.dart';
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
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addParty.
  ///
  /// In en, this message translates to:
  /// **'Add party'**
  String get addParty;

  /// No description provided for @addProduct.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get addProduct;

  /// No description provided for @addProducts.
  ///
  /// In en, this message translates to:
  /// **'Add products'**
  String get addProducts;

  /// No description provided for @addUser.
  ///
  /// In en, this message translates to:
  /// **'Add user'**
  String get addUser;

  /// No description provided for @addVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle'**
  String get addVehicle;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @allDates.
  ///
  /// In en, this message translates to:
  /// **'All dates'**
  String get allDates;

  /// No description provided for @allOrders.
  ///
  /// In en, this message translates to:
  /// **'All Orders'**
  String get allOrders;

  /// No description provided for @allOrdersHelp.
  ///
  /// In en, this message translates to:
  /// **'Every order, filters, summaries, Excel export'**
  String get allOrdersHelp;

  /// No description provided for @allProductsAdded.
  ///
  /// In en, this message translates to:
  /// **'All products are already on this order'**
  String get allProductsAdded;

  /// No description provided for @allSynced.
  ///
  /// In en, this message translates to:
  /// **'All orders synced'**
  String get allSynced;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Order Tracking'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel order'**
  String get cancelOrder;

  /// No description provided for @cancelOrderMessage.
  ///
  /// In en, this message translates to:
  /// **'The order will be kept but marked Cancelled. Continue?'**
  String get cancelOrderMessage;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @chooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose .xlsx file'**
  String get chooseFile;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @companyName.
  ///
  /// In en, this message translates to:
  /// **'Parker Water Products'**
  String get companyName;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmPassword;

  /// No description provided for @contactName.
  ///
  /// In en, this message translates to:
  /// **'Contact name'**
  String get contactName;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @dateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get dateTime;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @deactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get deactivate;

  /// No description provided for @defaultRate.
  ///
  /// In en, this message translates to:
  /// **'Default rate'**
  String get defaultRate;

  /// No description provided for @defaultRateHelp.
  ///
  /// In en, this message translates to:
  /// **'Used only when a party has no rate for this product'**
  String get defaultRateHelp;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @discardOrder.
  ///
  /// In en, this message translates to:
  /// **'Discard order?'**
  String get discardOrder;

  /// No description provided for @discardOrderMessage.
  ///
  /// In en, this message translates to:
  /// **'This order was rejected by the server and will be deleted from this phone.'**
  String get discardOrderMessage;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @downloadTemplate.
  ///
  /// In en, this message translates to:
  /// **'Download template'**
  String get downloadTemplate;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @editProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get editProduct;

  /// No description provided for @editVehicle.
  ///
  /// In en, this message translates to:
  /// **'Edit vehicle'**
  String get editVehicle;

  /// No description provided for @effectiveFrom.
  ///
  /// In en, this message translates to:
  /// **'Effective from'**
  String get effectiveFrom;

  /// No description provided for @errPartyRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a party'**
  String get errPartyRequired;

  /// No description provided for @errProductsRequired.
  ///
  /// In en, this message translates to:
  /// **'Add at least one product'**
  String get errProductsRequired;

  /// No description provided for @errQuantityRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a quantity for every product'**
  String get errQuantityRequired;

  /// No description provided for @errVehicleRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose a vehicle (or No vehicle)'**
  String get errVehicleRequired;

  /// No description provided for @exportExcel.
  ///
  /// In en, this message translates to:
  /// **'Export Excel'**
  String get exportExcel;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @group.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get group;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @historyCreated.
  ///
  /// In en, this message translates to:
  /// **'Order submitted'**
  String get historyCreated;

  /// No description provided for @importExcel.
  ///
  /// In en, this message translates to:
  /// **'Import from Excel'**
  String get importExcel;

  /// No description provided for @importHelp.
  ///
  /// In en, this message translates to:
  /// **'Bulk-load parties and rate lists'**
  String get importHelp;

  /// No description provided for @importIntro.
  ///
  /// In en, this message translates to:
  /// **'Upload an Excel file with a \"Parties\" sheet (Name, Contact Name, Phone, Address) and/or a \"Rates\" sheet (Party Name, Product Name, Rate, Effective From). Existing parties are matched by name and updated; rates are added with their effective date.'**
  String get importIntro;

  /// No description provided for @importNow.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importNow;

  /// No description provided for @importReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read that file. Use the .xlsx template.'**
  String get importReadError;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @initialPassword.
  ///
  /// In en, this message translates to:
  /// **'Initial password'**
  String get initialPassword;

  /// No description provided for @labelOptional.
  ///
  /// In en, this message translates to:
  /// **'Label (optional)'**
  String get labelOptional;

  /// No description provided for @lastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last edited'**
  String get lastUpdated;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @loginHelp.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password? Ask the admin to reset it.'**
  String get loginHelp;

  /// No description provided for @logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log out of this phone?'**
  String get logoutConfirm;

  /// No description provided for @markDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark delivered'**
  String get markDelivered;

  /// No description provided for @markSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Move back to Submitted'**
  String get markSubmitted;

  /// No description provided for @masterData.
  ///
  /// In en, this message translates to:
  /// **'Parties, products & rates'**
  String get masterData;

  /// No description provided for @mastersNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'Product and party lists are not on this phone yet. Connect to the internet once to download them.'**
  String get mastersNotLoaded;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @neverUpdated.
  ///
  /// In en, this message translates to:
  /// **'Not downloaded yet'**
  String get neverUpdated;

  /// No description provided for @newOrder.
  ///
  /// In en, this message translates to:
  /// **'New order'**
  String get newOrder;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get noMatches;

  /// No description provided for @noOrdersInRange.
  ///
  /// In en, this message translates to:
  /// **'No orders in this period'**
  String get noOrdersInRange;

  /// No description provided for @noOrdersMatch.
  ///
  /// In en, this message translates to:
  /// **'No orders match these filters'**
  String get noOrdersMatch;

  /// No description provided for @noOrdersToday.
  ///
  /// In en, this message translates to:
  /// **'No orders yet today.\nTap New order to add one.'**
  String get noOrdersToday;

  /// No description provided for @noVehicle.
  ///
  /// In en, this message translates to:
  /// **'No vehicle'**
  String get noVehicle;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @nothingHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHereYet;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline — orders will sync when back online'**
  String get offline;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @orderNo.
  ///
  /// In en, this message translates to:
  /// **'Order no'**
  String get orderNo;

  /// No description provided for @orderQueued.
  ///
  /// In en, this message translates to:
  /// **'Saved on phone'**
  String get orderQueued;

  /// No description provided for @orderQueuedMessage.
  ///
  /// In en, this message translates to:
  /// **'No connection right now. The order is saved and will sync automatically (shown as Pending sync).'**
  String get orderQueuedMessage;

  /// No description provided for @orderSaved.
  ///
  /// In en, this message translates to:
  /// **'Order submitted'**
  String get orderSaved;

  /// No description provided for @orderTaker.
  ///
  /// In en, this message translates to:
  /// **'Order taker'**
  String get orderTaker;

  /// No description provided for @orderUpdated.
  ///
  /// In en, this message translates to:
  /// **'Order updated'**
  String get orderUpdated;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @parties.
  ///
  /// In en, this message translates to:
  /// **'Parties'**
  String get parties;

  /// No description provided for @partiesHelp.
  ///
  /// In en, this message translates to:
  /// **'Customers, distributors and their rate lists'**
  String get partiesHelp;

  /// No description provided for @party.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get party;

  /// No description provided for @partyCreatedNowRates.
  ///
  /// In en, this message translates to:
  /// **'Party created. Set its rates in the Rate List tab.'**
  String get partyCreatedNowRates;

  /// No description provided for @partyName.
  ///
  /// In en, this message translates to:
  /// **'Party name'**
  String get partyName;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @passwordResetDone.
  ///
  /// In en, this message translates to:
  /// **'Password reset'**
  String get passwordResetDone;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDontMatch;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get pendingSync;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @product.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get product;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @productsHelp.
  ///
  /// In en, this message translates to:
  /// **'Product master: name, unit, default rate'**
  String get productsHelp;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get quantity;

  /// No description provided for @rateHistory.
  ///
  /// In en, this message translates to:
  /// **'Rate history'**
  String get rateHistory;

  /// No description provided for @rateList.
  ///
  /// In en, this message translates to:
  /// **'Rate List'**
  String get rateList;

  /// No description provided for @rateListHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap a product to set this party\'s rate. A new rate applies to orders from its effective date; older orders keep the rate they were saved with.'**
  String get rateListHelp;

  /// No description provided for @reactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get reactivate;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleOrderTaker.
  ///
  /// In en, this message translates to:
  /// **'Order Taker'**
  String get roleOrderTaker;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Type to search'**
  String get searchHint;

  /// No description provided for @searchOrders.
  ///
  /// In en, this message translates to:
  /// **'Order no, party, notes'**
  String get searchOrders;

  /// No description provided for @selectParty.
  ///
  /// In en, this message translates to:
  /// **'Select party'**
  String get selectParty;

  /// No description provided for @selectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Select vehicle'**
  String get selectVehicle;

  /// No description provided for @showingCached.
  ///
  /// In en, this message translates to:
  /// **'Offline — showing the last downloaded list'**
  String get showingCached;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get statusSubmitted;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get syncFailed;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @unitHint.
  ///
  /// In en, this message translates to:
  /// **'box, bottle, jar…'**
  String get unitHint;

  /// No description provided for @userId.
  ///
  /// In en, this message translates to:
  /// **'User ID'**
  String get userId;

  /// No description provided for @userIdHelp.
  ///
  /// In en, this message translates to:
  /// **'2–40 characters: letters, digits, . _ -'**
  String get userIdHelp;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @usersHelp.
  ///
  /// In en, this message translates to:
  /// **'Create logins, roles, reset passwords'**
  String get usersHelp;

  /// No description provided for @vehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicle;

  /// No description provided for @vehicleLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Tata Ace — Ramesh'**
  String get vehicleLabelHint;

  /// No description provided for @vehicleNumber.
  ///
  /// In en, this message translates to:
  /// **'Vehicle number'**
  String get vehicleNumber;

  /// No description provided for @vehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get vehicles;

  /// No description provided for @vehiclesHelp.
  ///
  /// In en, this message translates to:
  /// **'Vehicle list for the order form'**
  String get vehiclesHelp;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @addCount.
  ///
  /// In en, this message translates to:
  /// **'Add {count}'**
  String addCount(int count);

  /// No description provided for @byGroup.
  ///
  /// In en, this message translates to:
  /// **'By {group}'**
  String byGroup(String group);

  /// No description provided for @deactivateMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} will no longer be able to log in. Their orders stay in the system. Continue?'**
  String deactivateMessage(String name);

  /// No description provided for @editOrderNo.
  ///
  /// In en, this message translates to:
  /// **'Edit {orderNo}'**
  String editOrderNo(String orderNo);

  /// No description provided for @effectiveSince.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String effectiveSince(String date);

  /// No description provided for @exported.
  ///
  /// In en, this message translates to:
  /// **'Exported {file}'**
  String exported(String file);

  /// No description provided for @historyStatus.
  ///
  /// In en, this message translates to:
  /// **'{from} → {to}'**
  String historyStatus(String from, String to);

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Imported: {created} new parties, {updated} updated, {rates} rates saved'**
  String importDone(int created, int updated, int rates);

  /// No description provided for @importErrors.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 row was skipped:} other{{count} rows were skipped:}}'**
  String importErrors(int count);

  /// No description provided for @importPreview.
  ///
  /// In en, this message translates to:
  /// **'Found {parties} parties and {rates} rate rows'**
  String importPreview(int parties, int rates);

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more ({shown} of {total})'**
  String loadMore(int shown, int total);

  /// No description provided for @logoutPendingWarning.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 order has} other{{count} orders have}} not synced yet. They stay on this phone and sync after you log in again as the same user. Log out anyway?'**
  String logoutPendingWarning(int count);

  /// No description provided for @ordersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No orders} =1{1 order} other{{count} orders}}'**
  String ordersCount(int count);

  /// No description provided for @pendingOrders.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 order waiting to sync} other{{count} orders waiting to sync}}'**
  String pendingOrders(int count);

  /// No description provided for @ratePerUnit.
  ///
  /// In en, this message translates to:
  /// **'Rate per {unit}'**
  String ratePerUnit(String unit);

  /// No description provided for @repeatLastOrder.
  ///
  /// In en, this message translates to:
  /// **'Repeat last order ({count, plural, =1{1 product} other{{count} products}})'**
  String repeatLastOrder(int count);

  /// No description provided for @showInactive.
  ///
  /// In en, this message translates to:
  /// **'Show inactive ({count})'**
  String showInactive(int count);

  /// No description provided for @statusChangedTo.
  ///
  /// In en, this message translates to:
  /// **'Status changed to {status}'**
  String statusChangedTo(String status);

  /// No description provided for @totalItems.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unit} other{{count} units}}'**
  String totalItems(int count);

  /// No description provided for @upcomingRate.
  ///
  /// In en, this message translates to:
  /// **'{rate} from {date}'**
  String upcomingRate(String rate, String date);

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {when}'**
  String updatedAt(String when);

  /// No description provided for @usingDefaultRate.
  ///
  /// In en, this message translates to:
  /// **'No party rate — uses default {rate}'**
  String usingDefaultRate(String rate);

  /// No description provided for @decrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decrease;

  /// No description provided for @increase.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increase;
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
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
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
