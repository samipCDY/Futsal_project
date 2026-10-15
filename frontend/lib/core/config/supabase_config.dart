/// This key (labeled "anon" or "publishable" depending on dashboard
/// version) is safe to ship in the compiled app — unlike a service_role
/// key, it's designed to be public and is constrained by the RLS policies
/// defined on each table. Not gitignored for that reason.
///
/// Get these from your Supabase project: Project Settings -> API.
class SupabaseConfig {
  static const url = 'https://oauxglvqzjjaaezqapkl.supabase.co';
  static const anonKey = 'sb_publishable_YYOZ8UT5vG7g-fJ-p8Ts_A_6AxG9ypi';
}
