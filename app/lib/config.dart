/// Build-time configuration. Pass with --dart-define (see README):
///   flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// The anon/publishable key is public by design; row-level security protects data.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Login is `<user id>@<loginDomain>` in Supabase Auth.
  static const loginDomain = 'parker.local';

  /// Plant time zone (must match plant_tz() in the database). India has no DST.
  static const plantUtcOffset = Duration(hours: 5, minutes: 30);

  static const currencySymbol = '₹';
  static const currencyLocale = 'en_IN';

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
