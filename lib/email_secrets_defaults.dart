/// Email Secrets Defaults
/// 
/// Safe default values for email credentials.
/// Real credentials should be provided via:
/// 1. dart-define: EMAIL_SENDER and EMAIL_APP_PASSWORD
/// 2. Email Setup UI in the app
/// 
/// These empty defaults prevent build failures when email_secrets.local.dart is missing
/// while keeping real credentials out of source control.

const String emailSecretsSender = '';
const String emailSecretsAppPassword = '';
