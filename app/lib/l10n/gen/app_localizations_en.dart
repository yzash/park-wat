// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get account => 'Account';

  @override
  String get active => 'Active';

  @override
  String get add => 'Add';

  @override
  String get addParty => 'Add party';

  @override
  String get addProduct => 'Add product';

  @override
  String get addProducts => 'Add products';

  @override
  String get addUser => 'Add user';

  @override
  String get addVehicle => 'Add vehicle';

  @override
  String get address => 'Address';

  @override
  String get admin => 'Admin';

  @override
  String get allDates => 'All dates';

  @override
  String get allOrders => 'All Orders';

  @override
  String get allOrdersHelp => 'Every order, filters, summaries, Excel export';

  @override
  String get allProductsAdded => 'All products are already on this order';

  @override
  String get allSynced => 'All orders synced';

  @override
  String get appTitle => 'Order Tracking';

  @override
  String get cancel => 'Cancel';

  @override
  String get cancelOrder => 'Cancel order';

  @override
  String get cancelOrderMessage =>
      'The order will be kept but marked Cancelled. Continue?';

  @override
  String get changePassword => 'Change password';

  @override
  String get chooseFile => 'Choose .xlsx file';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get companyName => 'Parker Water Products';

  @override
  String get confirmPassword => 'Confirm new password';

  @override
  String get contactName => 'Contact name';

  @override
  String get create => 'Create';

  @override
  String get currentPassword => 'Current password';

  @override
  String get dateTime => 'Date & time';

  @override
  String get day => 'Day';

  @override
  String get deactivate => 'Deactivate';

  @override
  String get defaultRate => 'Default rate';

  @override
  String get defaultRateHelp =>
      'Used only when a party has no rate for this product';

  @override
  String get details => 'Details';

  @override
  String get discard => 'Discard';

  @override
  String get discardOrder => 'Discard order?';

  @override
  String get discardOrderMessage =>
      'This order was rejected by the server and will be deleted from this phone.';

  @override
  String get done => 'Done';

  @override
  String get downloadTemplate => 'Download template';

  @override
  String get edit => 'Edit';

  @override
  String get editProduct => 'Edit product';

  @override
  String get editVehicle => 'Edit vehicle';

  @override
  String get effectiveFrom => 'Effective from';

  @override
  String get errPartyRequired => 'Choose a party';

  @override
  String get errProductsRequired => 'Add at least one product';

  @override
  String get errQuantityRequired => 'Enter a quantity for every product';

  @override
  String get errVehicleRequired => 'Choose a vehicle (or No vehicle)';

  @override
  String get exportExcel => 'Export Excel';

  @override
  String get fullName => 'Full name';

  @override
  String get group => 'Group';

  @override
  String get history => 'History';

  @override
  String get historyCreated => 'Order submitted';

  @override
  String get importExcel => 'Import from Excel';

  @override
  String get importHelp => 'Bulk-load parties and rate lists';

  @override
  String get importIntro =>
      'Upload an Excel file with a \"Parties\" sheet (Name, Contact Name, Phone, Address) and/or a \"Rates\" sheet (Party Name, Product Name, Rate, Effective From). Existing parties are matched by name and updated; rates are added with their effective date.';

  @override
  String get importNow => 'Import';

  @override
  String get importReadError =>
      'Could not read that file. Use the .xlsx template.';

  @override
  String get inactive => 'Inactive';

  @override
  String get initialPassword => 'Initial password';

  @override
  String get labelOptional => 'Label (optional)';

  @override
  String get lastUpdated => 'Last edited';

  @override
  String get logIn => 'Log in';

  @override
  String get logOut => 'Log out';

  @override
  String get loginHelp => 'Forgot your password? Ask the admin to reset it.';

  @override
  String get logoutConfirm => 'Log out of this phone?';

  @override
  String get markDelivered => 'Mark delivered';

  @override
  String get markSubmitted => 'Move back to Submitted';

  @override
  String get masterData => 'Parties, products & rates';

  @override
  String get mastersNotLoaded =>
      'Product and party lists are not on this phone yet. Connect to the internet once to download them.';

  @override
  String get myOrders => 'My Orders';

  @override
  String get name => 'Name';

  @override
  String get neverUpdated => 'Not downloaded yet';

  @override
  String get newOrder => 'New order';

  @override
  String get newPassword => 'New password';

  @override
  String get noMatches => 'No matches';

  @override
  String get noOrdersInRange => 'No orders in this period';

  @override
  String get noOrdersMatch => 'No orders match these filters';

  @override
  String get noOrdersToday => 'No orders yet today.\nTap New order to add one.';

  @override
  String get noVehicle => 'No vehicle';

  @override
  String get notes => 'Notes';

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get nothingHereYet => 'Nothing here yet';

  @override
  String get offline => 'Offline — orders will sync when back online';

  @override
  String get ok => 'OK';

  @override
  String get online => 'Online';

  @override
  String get order => 'Order';

  @override
  String get orderNo => 'Order no';

  @override
  String get orderQueued => 'Saved on phone';

  @override
  String get orderQueuedMessage =>
      'No connection right now. The order is saved and will sync automatically (shown as Pending sync).';

  @override
  String get orderSaved => 'Order submitted';

  @override
  String get orderTaker => 'Order taker';

  @override
  String get orderUpdated => 'Order updated';

  @override
  String get orders => 'Orders';

  @override
  String get parties => 'Parties';

  @override
  String get partiesHelp => 'Customers, distributors and their rate lists';

  @override
  String get party => 'Party';

  @override
  String get partyCreatedNowRates =>
      'Party created. Set its rates in the Rate List tab.';

  @override
  String get partyName => 'Party name';

  @override
  String get password => 'Password';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get passwordResetDone => 'Password reset';

  @override
  String get passwordTooShort => 'At least 8 characters';

  @override
  String get passwordsDontMatch => 'Passwords do not match';

  @override
  String get pendingSync => 'Pending sync';

  @override
  String get phone => 'Phone';

  @override
  String get product => 'Product';

  @override
  String get products => 'Products';

  @override
  String get productsHelp => 'Product master: name, unit, default rate';

  @override
  String get quantity => 'Qty';

  @override
  String get rateHistory => 'Rate history';

  @override
  String get rateList => 'Rate List';

  @override
  String get rateListHelp =>
      'Tap a product to set this party\'s rate. A new rate applies to orders from its effective date; older orders keep the rate they were saved with.';

  @override
  String get reactivate => 'Reactivate';

  @override
  String get refresh => 'Refresh';

  @override
  String get remove => 'Remove';

  @override
  String get required => 'Required';

  @override
  String get resetPassword => 'Reset password';

  @override
  String get retry => 'Retry';

  @override
  String get role => 'Role';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleOrderTaker => 'Order Taker';

  @override
  String get save => 'Save';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get saved => 'Saved';

  @override
  String get searchHint => 'Type to search';

  @override
  String get searchOrders => 'Order no, party, notes';

  @override
  String get selectParty => 'Select party';

  @override
  String get selectVehicle => 'Select vehicle';

  @override
  String get showingCached => 'Offline — showing the last downloaded list';

  @override
  String get status => 'Status';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusSubmitted => 'Submitted';

  @override
  String get submit => 'Submit';

  @override
  String get summary => 'Summary';

  @override
  String get syncFailed => 'Sync failed';

  @override
  String get today => 'Today';

  @override
  String get total => 'Total';

  @override
  String get unit => 'Unit';

  @override
  String get unitHint => 'box, bottle, jar…';

  @override
  String get userId => 'User ID';

  @override
  String get userIdHelp => '2–40 characters: letters, digits, . _ -';

  @override
  String get users => 'Users';

  @override
  String get usersHelp => 'Create logins, roles, reset passwords';

  @override
  String get vehicle => 'Vehicle';

  @override
  String get vehicleLabelHint => 'e.g. Tata Ace — Ramesh';

  @override
  String get vehicleNumber => 'Vehicle number';

  @override
  String get vehicles => 'Vehicles';

  @override
  String get vehiclesHelp => 'Vehicle list for the order form';

  @override
  String get you => 'You';

  @override
  String addCount(int count) {
    return 'Add $count';
  }

  @override
  String byGroup(String group) {
    return 'By $group';
  }

  @override
  String deactivateMessage(String name) {
    return '$name will no longer be able to log in. Their orders stay in the system. Continue?';
  }

  @override
  String editOrderNo(String orderNo) {
    return 'Edit $orderNo';
  }

  @override
  String effectiveSince(String date) {
    return 'Since $date';
  }

  @override
  String exported(String file) {
    return 'Exported $file';
  }

  @override
  String historyStatus(String from, String to) {
    return '$from → $to';
  }

  @override
  String importDone(int created, int updated, int rates) {
    return 'Imported: $created new parties, $updated updated, $rates rates saved';
  }

  @override
  String importErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows were skipped:',
      one: '1 row was skipped:',
    );
    return '$_temp0';
  }

  @override
  String importPreview(int parties, int rates) {
    return 'Found $parties parties and $rates rate rows';
  }

  @override
  String loadMore(int shown, int total) {
    return 'Load more ($shown of $total)';
  }

  @override
  String logoutPendingWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders have',
      one: '1 order has',
    );
    return '$_temp0 not synced yet. They stay on this phone and sync after you log in again as the same user. Log out anyway?';
  }

  @override
  String ordersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders',
      one: '1 order',
      zero: 'No orders',
    );
    return '$_temp0';
  }

  @override
  String pendingOrders(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orders waiting to sync',
      one: '1 order waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String ratePerUnit(String unit) {
    return 'Rate per $unit';
  }

  @override
  String repeatLastOrder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count products',
      one: '1 product',
    );
    return 'Repeat last order ($_temp0)';
  }

  @override
  String showInactive(int count) {
    return 'Show inactive ($count)';
  }

  @override
  String statusChangedTo(String status) {
    return 'Status changed to $status';
  }

  @override
  String totalItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count units',
      one: '1 unit',
    );
    return '$_temp0';
  }

  @override
  String upcomingRate(String rate, String date) {
    return '$rate from $date';
  }

  @override
  String updatedAt(String when) {
    return 'Updated $when';
  }

  @override
  String usingDefaultRate(String rate) {
    return 'No party rate — uses default $rate';
  }

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';
}
