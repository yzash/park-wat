import 'package:flutter/widgets.dart';

import '../l10n/gen/app_localizations.dart';

export '../l10n/gen/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get t => AppLocalizations.of(this);
}
