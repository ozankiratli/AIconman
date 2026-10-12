-- Tests of accounts, settings, sessions and identities, as the owner role, in
-- one transaction that is rolled back. Expects a freshly built and seeded
-- schema with self sign-up open. Session tokens and password hashes are
-- made up by the helpers: pg_temp.t('alex') is a token's hash, pg_temp.pw('alex')
-- a password's.

BEGIN;
\ir helpers.sql

-- Seeding -------------------------------------------------------------------

SELECT pg_temp.ok('seeded: Nextcloud is a provider',
  EXISTS (SELECT 1 FROM providers WHERE provider = 'nextcloud'));
SELECT pg_temp.ok('seeded: self sign-up is open', sign_up_open());

-- Signing up ----------------------------------------------------------------

SELECT sign_up_password('alex', NULL, 'salt-alex', pg_temp.pw('alex'), pg_temp.t('alex'), '1 hour', '1 day') AS alex \gset
SELECT pg_temp.ok('an account id is eight lowercase letters and digits', :'alex' ~ '^[a-z0-9]{8}$');
SELECT pg_temp.ok('the first account is the admin',
  (SELECT role FROM accounts WHERE account_id = :'alex') = 'admin');
SELECT pg_temp.ok('the display name is the username when none is given',
  (SELECT display_name FROM accounts WHERE account_id = :'alex') = 'alex');

SELECT sign_up_password('sam', '  Sam S.  ', 'salt-sam', pg_temp.pw('sam'), pg_temp.t('sam'), '1 hour', '1 day') AS sam \gset
SELECT pg_temp.ok('the second account is a member',
  (SELECT role FROM accounts WHERE account_id = :'sam') = 'member');
SELECT pg_temp.ok('a display name given is kept, trimmed',
  (SELECT display_name FROM accounts WHERE account_id = :'sam') = 'Sam S.');
SELECT pg_temp.ok('two accounts have different ids', :'alex' <> :'sam');

SELECT pg_temp.refused('a username already taken',
  $$SELECT sign_up_password('alex', NULL, 's', pg_temp.pw('x'), pg_temp.t('x'), '1 hour', '1 day')$$, 'username_taken');
SELECT pg_temp.refused('a username with an uppercase letter',
  $$SELECT sign_up_password('Kim', NULL, 's', pg_temp.pw('x'), pg_temp.t('x'), '1 hour', '1 day')$$, 'username_invalid');
SELECT pg_temp.refused('a username with a dot',
  $$SELECT sign_up_password('k.m', NULL, 's', pg_temp.pw('x'), pg_temp.t('x'), '1 hour', '1 day')$$, 'username_invalid');
SELECT pg_temp.refused('a username with a space',
  $$SELECT sign_up_password('k m', NULL, 's', pg_temp.pw('x'), pg_temp.t('x'), '1 hour', '1 day')$$, 'username_invalid');
SELECT pg_temp.refused('an empty username',
  $$SELECT sign_up_password('', NULL, 's', pg_temp.pw('x'), pg_temp.t('x'), '1 hour', '1 day')$$, 'username_invalid');
SELECT pg_temp.refused('no username',
  $$SELECT sign_up_password(NULL, NULL, 's', pg_temp.pw('x'), pg_temp.t('x'), '1 hour', '1 day')$$, 'username_invalid');
SELECT pg_temp.refused('a username of 51 characters',
  $$SELECT sign_up_password(repeat('a', 51), NULL, 's', pg_temp.pw('x'), pg_temp.t('x'), '1 hour', '1 day')$$, 'username_invalid');
SELECT pg_temp.ok('a username of 50 characters, with digits, a dash and an underscore',
  sign_up_password(repeat('a', 46) || '-_9', NULL, 's', pg_temp.pw('x'), pg_temp.t('long'), '1 hour', '1 day') IS NOT NULL);
SELECT pg_temp.refused('a display name with a line break',
  $$SELECT sign_up_password('kim', E'Kim\nK', 's', pg_temp.pw('x'), pg_temp.t('x'), '1 hour', '1 day')$$, 'display_name_invalid');
SELECT pg_temp.refused('a display name of 101 characters',
  $$SELECT sign_up_password('kim', repeat('k', 101), 's', pg_temp.pw('x'), pg_temp.t('x'), '1 hour', '1 day')$$, 'display_name_invalid');
SELECT pg_temp.refused('a sign-up without a password',
  $$SELECT sign_up_password('kim', NULL, NULL, NULL, pg_temp.t('x'), '1 hour', '1 day')$$, 'password_invalid');
SELECT pg_temp.refused('a password with an empty salt',
  $$SELECT sign_up_password('kim', NULL, '', pg_temp.pw('x'), pg_temp.t('x'), '1 hour', '1 day')$$, 'password_invalid');

SELECT pg_temp.refused('an account id cannot be changed, even by the owner role',
  format('UPDATE accounts SET account_id = %L WHERE account_id = %L', 'zzzzzzzz', :'alex'), 'account_id_fixed');

-- Settings and closing sign-up -------------------------------------------------

SELECT pg_temp.refused('a member cannot change a setting',
  $$SELECT admin_set_setting(pg_temp.t('sam'), 'allow_auto_signup', 'false')$$, 'not_admin');
SELECT pg_temp.refused('a setting that was not seeded',
  $$SELECT admin_set_setting(pg_temp.t('alex'), 'no_such_setting', 'false')$$, 'setting_unknown');
SELECT pg_temp.refused('a setting given a value of another type',
  $$SELECT admin_set_setting(pg_temp.t('alex'), 'allow_auto_signup', '"no"')$$, 'setting_invalid');
SELECT admin_set_setting(pg_temp.t('alex'), 'allow_auto_signup', 'false');
SELECT pg_temp.ok('the admin closes self sign-up', NOT sign_up_open());
SELECT pg_temp.ok('the change records who made it',
  (SELECT changed_by FROM admin_settings(pg_temp.t('alex')) WHERE key = 'allow_auto_signup') = 'alex');
SELECT pg_temp.refused('signing up with a password while sign-up is closed',
  $$SELECT sign_up_password('kim', NULL, 's', pg_temp.pw('x'), pg_temp.t('x'), '1 hour', '1 day')$$, 'sign_up_closed');
SELECT pg_temp.refused('signing up through Nextcloud while sign-up is closed',
  $$SELECT sign_up_identity('nextcloud', 'nc-kim', 'Kim', 'kim', NULL, pg_temp.t('x'), '1 hour', '1 day')$$, 'sign_up_closed');
SELECT pg_temp.refused('a member cannot create an account',
  $$SELECT admin_create_account(pg_temp.t('sam'), 'kim', NULL, 'salt-kim0', pg_temp.pw('kim0'))$$, 'not_admin');
SELECT admin_create_account(pg_temp.t('alex'), 'kim', 'Kim', 'salt-kim0', pg_temp.pw('kim0')) AS kim \gset
SELECT pg_temp.ok('the admin creates an account while sign-up is closed, a member',
  (SELECT role FROM accounts WHERE account_id = :'kim') = 'member');
SELECT pg_temp.ok('  which must change its password',
  (SELECT must_change_password FROM accounts WHERE account_id = :'kim'));
SELECT admin_set_setting(pg_temp.t('alex'), 'allow_auto_signup', 'true');
SELECT pg_temp.ok('the admin opens self sign-up again', sign_up_open());

-- Signing in --------------------------------------------------------------------

SELECT pg_temp.ok('password_salt gives the salt the password was hashed with', password_salt('alex') = 'salt-alex');
SELECT pg_temp.ok('password_salt of an unknown username is NULL', password_salt('nobody') IS NULL);
SELECT pg_temp.ok('signing in with the right hash',
  sign_in_password('alex', pg_temp.pw('alex'), pg_temp.t('alex2'), '1 hour', '1 day') = :'alex');
SELECT pg_temp.refused('signing in with the wrong hash',
  $$SELECT sign_in_password('alex', pg_temp.pw('wrong'), pg_temp.t('x'), '1 hour', '1 day')$$, 'wrong_credentials');
SELECT pg_temp.refused('signing in with no hash',
  $$SELECT sign_in_password('alex', NULL, pg_temp.t('x'), '1 hour', '1 day')$$, 'wrong_credentials');
SELECT pg_temp.refused('signing in with an unknown username',
  $$SELECT sign_in_password('nobody', pg_temp.pw('alex'), pg_temp.t('x'), '1 hour', '1 day')$$, 'wrong_credentials');
SELECT pg_temp.refused('a session token hash that is not 32 bytes',
  $$SELECT sign_in_password('alex', pg_temp.pw('alex'), '\x0102', '1 hour', '1 day')$$, 'token_hash_invalid');
SELECT pg_temp.refused('a session with no idle timeout',
  $$SELECT sign_in_password('alex', pg_temp.pw('alex'), pg_temp.t('x'), '0', '1 day')$$, 'session_length_invalid');

-- Sessions ------------------------------------------------------------------------

SELECT pg_temp.ok('a session is checked, and gives its account',
  (SELECT username FROM session_check(pg_temp.t('alex'))) = 'alex');
SELECT pg_temp.refused('an unknown session',
  $$SELECT session_check(pg_temp.t('nobody'))$$, 'session_invalid');

UPDATE sessions SET last_used_at = now() - interval '2 hours' WHERE token_hash = pg_temp.t('alex2');
SELECT pg_temp.refused('a session left unused past its idle timeout',
  $$SELECT session_check(pg_temp.t('alex2'))$$, 'session_invalid');

UPDATE sessions SET last_used_at = now() - interval '30 minutes' WHERE token_hash = pg_temp.t('alex');
SELECT session_check(pg_temp.t('alex'));
SELECT pg_temp.ok('using a session restarts its idle timeout',
  (SELECT last_used_at FROM sessions WHERE token_hash = pg_temp.t('alex')) = now());

SELECT sign_in_password('alex', pg_temp.pw('alex'), pg_temp.t('alex3'), '1 hour', '1 day');
UPDATE sessions SET expires_at = now() WHERE token_hash = pg_temp.t('alex3');
SELECT pg_temp.refused('a session past its expiry, however recently used',
  $$SELECT session_check(pg_temp.t('alex3'))$$, 'session_invalid');

SELECT sign_in_password('alex', pg_temp.pw('alex'), pg_temp.t('alex4'), '1 hour', '1 day');
SELECT sign_out(pg_temp.t('alex4'));
SELECT pg_temp.refused('a session signed out of',
  $$SELECT session_check(pg_temp.t('alex4'))$$, 'session_invalid');

SELECT sign_in_password('alex', pg_temp.pw('alex'), pg_temp.t('alex5'), '1 hour', '1 day');
SELECT pg_temp.ok('signing in deletes the sessions that can no longer be used',
  NOT EXISTS (SELECT 1 FROM sessions WHERE token_hash IN (pg_temp.t('alex2'), pg_temp.t('alex3'), pg_temp.t('alex4'))));

SELECT pg_temp.ok('signing out everywhere else revokes the other sessions',
  sign_out_others(pg_temp.t('alex')) = 1);
SELECT pg_temp.refused('  so the other session is refused',
  $$SELECT session_check(pg_temp.t('alex5'))$$, 'session_invalid');
SELECT pg_temp.ok('  and this one still works',
  (SELECT account_id FROM session_check(pg_temp.t('alex'))) = :'alex');

-- Changing a password --------------------------------------------------------------

SELECT sign_in_password('kim', pg_temp.pw('kim0'), pg_temp.t('kim'), '1 hour', '1 day');
SELECT sign_in_password('kim', pg_temp.pw('kim0'), pg_temp.t('kim-b'), '1 hour', '1 day');
SELECT pg_temp.ok('the session of an account that must change its password says so',
  (SELECT must_change_password FROM session_check(pg_temp.t('kim'))));
SELECT pg_temp.refused('  and nothing else is allowed until it does',
  $$SELECT set_theme(pg_temp.t('kim'), 'dark')$$, 'password_change_required');
SELECT set_password(pg_temp.t('kim'), NULL, 'salt-kim1', pg_temp.pw('kim1'));
SELECT pg_temp.ok('the first password is changed without giving it again',
  NOT (SELECT must_change_password FROM session_check(pg_temp.t('kim'))));
SELECT pg_temp.refused('  which revokes the other sessions',
  $$SELECT session_check(pg_temp.t('kim-b'))$$, 'session_invalid');
SELECT set_theme(pg_temp.t('kim'), 'dark-hc');
SELECT pg_temp.ok('  and then the account can act',
  (SELECT theme FROM session_check(pg_temp.t('kim'))) = 'dark-hc');
SELECT pg_temp.refused('changing a password with the wrong current one',
  $$SELECT set_password(pg_temp.t('kim'), pg_temp.pw('wrong'), 'salt-kim2', pg_temp.pw('kim2'))$$, 'current_password_wrong');
SELECT pg_temp.refused('changing a password with none given as the current one',
  $$SELECT set_password(pg_temp.t('kim'), NULL, 'salt-kim2', pg_temp.pw('kim2'))$$, 'current_password_wrong');
SELECT set_password(pg_temp.t('kim'), pg_temp.pw('kim1'), 'salt-kim2', pg_temp.pw('kim2'));
SELECT pg_temp.ok('changing a password with the right current one',
  password_salt('kim') = 'salt-kim2');
SELECT pg_temp.refused('a new password not given',
  $$SELECT set_password(pg_temp.t('kim'), pg_temp.pw('kim2'), NULL, NULL)$$, 'password_invalid');
SELECT pg_temp.refused('a theme that does not exist',
  $$SELECT set_theme(pg_temp.t('kim'), 'blue')$$, 'theme_invalid');

-- One's own username and display name ---------------------------------------------

SELECT set_username(pg_temp.t('sam'), 'samuel');
SELECT pg_temp.ok('a person changes their own username, and the account id stays',
  (SELECT username FROM accounts WHERE account_id = :'sam') = 'samuel');
SELECT pg_temp.refused('a username already taken',
  $$SELECT set_username(pg_temp.t('sam'), 'alex')$$, 'username_taken');
SELECT pg_temp.refused('a username with an uppercase letter',
  $$SELECT set_username(pg_temp.t('sam'), 'Samuel')$$, 'username_invalid');
SELECT set_display_name(pg_temp.t('sam'), '  Samuel S.  ');
SELECT pg_temp.ok('a display name is changed, trimmed',
  (SELECT display_name FROM accounts WHERE account_id = :'sam') = 'Samuel S.');
SELECT pg_temp.refused('a display name of only spaces',
  $$SELECT set_display_name(pg_temp.t('sam'), '   ')$$, 'display_name_invalid');
SELECT pg_temp.refused('no display name',
  $$SELECT set_display_name(pg_temp.t('sam'), NULL)$$, 'display_name_invalid');

-- The admin role ----------------------------------------------------------------------

SELECT pg_temp.refused('the only admin cannot give up the role',
  $$SELECT give_up_admin(pg_temp.t('alex'))$$, 'last_admin');
SELECT pg_temp.refused('a member has no admin role to give up',
  $$SELECT give_up_admin(pg_temp.t('sam'))$$, 'not_admin');
SELECT pg_temp.refused('a member cannot make an admin',
  format('SELECT admin_make_admin(pg_temp.t(%L), %L)', 'sam', :'kim'), 'not_admin');
SELECT admin_make_admin(pg_temp.t('alex'), :'sam');
SELECT pg_temp.ok('an admin makes another account an admin',
  (SELECT role FROM accounts WHERE account_id = :'sam') = 'admin');
SELECT pg_temp.refused('an admin cannot deactivate another admin',
  format('SELECT admin_set_active(pg_temp.t(%L), %L, false)', 'alex', :'sam'), 'admin_account');
SELECT pg_temp.refused('an admin cannot delete another admin',
  format('SELECT admin_delete_account(pg_temp.t(%L), %L)', 'alex', :'sam'), 'admin_account');
SELECT give_up_admin(pg_temp.t('sam'));
SELECT pg_temp.ok('an admin who is not the only one gives up the role',
  (SELECT role FROM accounts WHERE account_id = :'sam') = 'member');
SELECT pg_temp.refused('an admin cannot deactivate themselves',
  format('SELECT admin_set_active(pg_temp.t(%L), %L, false)', 'alex', :'alex'), 'not_self');
SELECT pg_temp.refused('an admin cannot delete themselves through administration',
  format('SELECT admin_delete_account(pg_temp.t(%L), %L)', 'alex', :'alex'), 'not_self');
SELECT pg_temp.refused('an account id that does not exist',
  $$SELECT admin_make_admin(pg_temp.t('alex'), 'zzzzzzzz')$$, 'no_such_account');
UPDATE accounts SET created_at = now() - interval '1 day' WHERE account_id = :'kim';
SELECT pg_temp.ok('the admin lists every account, oldest first, then by username',
  (SELECT array_agg(username ORDER BY n)
   FROM admin_accounts(pg_temp.t('alex')) WITH ORDINALITY AS r(i, username, d, ro, ac, m, h, ids, c, n))
  = ARRAY['kim', repeat('a', 46) || '-_9', 'alex', 'samuel']);
SELECT pg_temp.refused('a member cannot list the accounts',
  $$SELECT admin_accounts(pg_temp.t('sam'))$$, 'not_admin');

-- Deactivating, and resetting a password ----------------------------------------------

SELECT admin_set_active(pg_temp.t('alex'), :'sam', false);
SELECT pg_temp.refused('deactivating an account revokes its sessions',
  $$SELECT session_check(pg_temp.t('sam'))$$, 'session_invalid');
SELECT pg_temp.refused('  and it cannot sign in',
  $$SELECT sign_in_password('samuel', pg_temp.pw('sam'), pg_temp.t('x'), '1 hour', '1 day')$$, 'deactivated');
SELECT pg_temp.refused('  or be made an admin',
  format('SELECT admin_make_admin(pg_temp.t(%L), %L)', 'alex', :'sam'), 'deactivated');
SELECT admin_set_active(pg_temp.t('alex'), :'sam', true);
SELECT pg_temp.ok('a reactivated account signs in again',
  sign_in_password('samuel', pg_temp.pw('sam'), pg_temp.t('sam2'), '1 hour', '1 day') = :'sam');

SELECT admin_reset_password(pg_temp.t('alex'), :'kim', 'salt-kim3', pg_temp.pw('kim3'));
SELECT pg_temp.ok('a reset password must be changed at the next sign-in',
  (SELECT must_change_password FROM accounts WHERE account_id = :'kim'));
SELECT pg_temp.refused('  and the reset revokes the account''s sessions',
  $$SELECT session_check(pg_temp.t('kim'))$$, 'session_invalid');
SELECT pg_temp.refused('  so the old password no longer signs in',
  $$SELECT sign_in_password('kim', pg_temp.pw('kim2'), pg_temp.t('x'), '1 hour', '1 day')$$, 'wrong_credentials');
SELECT pg_temp.ok('  and the new one does',
  sign_in_password('kim', pg_temp.pw('kim3'), pg_temp.t('kim2'), '1 hour', '1 day') = :'kim');

-- Nextcloud ------------------------------------------------------------------------------

SELECT sign_up_identity('nextcloud', 'nc-lee', 'Lee on Nextcloud', 'lee', NULL, pg_temp.t('lee'), '1 hour', '1 day') AS lee \gset
SELECT pg_temp.ok('signing up through Nextcloud makes an account with no password',
  NOT (SELECT has_password FROM session_check(pg_temp.t('lee'))));
SELECT pg_temp.ok('  linked to the Nextcloud account',
  (SELECT identities FROM session_check(pg_temp.t('lee'))) = '{"nextcloud": "Lee on Nextcloud"}'::jsonb);
SELECT pg_temp.ok('signing in through Nextcloud',
  sign_in_identity('nextcloud', 'nc-lee', 'Lee L.', pg_temp.t('lee2'), '1 hour', '1 day') = :'lee');
SELECT pg_temp.ok('  keeps the label up to date',
  (SELECT label FROM identities WHERE subject = 'nc-lee') = 'Lee L.');
SELECT pg_temp.refused('signing in through Nextcloud with no account linked',
  $$SELECT sign_in_identity('nextcloud', 'nc-nobody', 'Nobody', pg_temp.t('x'), '1 hour', '1 day')$$, 'no_account');
SELECT pg_temp.refused('signing in with a password on an account that has none',
  $$SELECT sign_in_password('lee', pg_temp.pw('lee'), pg_temp.t('x'), '1 hour', '1 day')$$, 'wrong_credentials');
SELECT pg_temp.refused('linking a second Nextcloud account',
  $$SELECT link_identity(pg_temp.t('lee'), 'nextcloud', 'nc-other', 'Other')$$, 'already_linked');
SELECT pg_temp.refused('linking a Nextcloud account linked to someone else',
  $$SELECT link_identity(pg_temp.t('alex'), 'nextcloud', 'nc-lee', 'Lee')$$, 'identity_taken');
SELECT pg_temp.refused('linking a provider that does not exist',
  $$SELECT link_identity(pg_temp.t('alex'), 'elsewhere', 'x-1', 'X')$$, 'provider_unknown');
SELECT link_identity(pg_temp.t('alex'), 'nextcloud', 'nc-alex', 'Alex on Nextcloud');
SELECT pg_temp.ok('a person links their own account to Nextcloud',
  (SELECT identities FROM session_check(pg_temp.t('alex'))) ? 'nextcloud');
SELECT pg_temp.refused('unlinking the only way an account signs in',
  $$SELECT unlink_identity(pg_temp.t('lee'), 'nextcloud')$$, 'last_sign_in');
SELECT pg_temp.refused('unlinking a provider not linked',
  $$SELECT unlink_identity(pg_temp.t('sam2'), 'nextcloud')$$, 'not_linked');
SELECT set_password(pg_temp.t('lee'), NULL, 'salt-lee', pg_temp.pw('lee'));
SELECT unlink_identity(pg_temp.t('lee'), 'nextcloud');
SELECT pg_temp.ok('an account with a password set unlinks Nextcloud',
  (SELECT identities FROM session_check(pg_temp.t('lee'))) = '{}'::jsonb);

SELECT sign_up_identity('nextcloud', 'nc-pat', 'Pat', 'pat', NULL, pg_temp.t('pat'), '1 hour', '1 day') AS pat \gset
SELECT admin_set_active(pg_temp.t('alex'), :'pat', false);
SELECT pg_temp.refused('a deactivated account cannot sign in through Nextcloud',
  $$SELECT sign_in_identity('nextcloud', 'nc-pat', 'Pat', pg_temp.t('x'), '1 hour', '1 day')$$, 'deactivated');

-- Deleting accounts ------------------------------------------------------------------------

SELECT admin_delete_account(pg_temp.t('alex'), :'pat');
SELECT pg_temp.ok('the admin deletes an account',
  NOT EXISTS (SELECT 1 FROM accounts WHERE account_id = :'pat'));
SELECT pg_temp.ok('  with its identities and sessions',
  NOT EXISTS (SELECT 1 FROM identities WHERE account_id = :'pat')
  AND NOT EXISTS (SELECT 1 FROM sessions WHERE account_id = :'pat'));
SELECT pg_temp.refused('deleting one''s account with the wrong username typed',
  $$SELECT delete_own_account(pg_temp.t('sam2'), 'sam')$$, 'confirmation_mismatch');
SELECT pg_temp.ok('a person deletes their own account',
  delete_own_account(pg_temp.t('sam2'), 'samuel') = :'sam');
SELECT pg_temp.ok('  which is gone, with its sessions',
  NOT EXISTS (SELECT 1 FROM accounts WHERE account_id = :'sam')
  AND NOT EXISTS (SELECT 1 FROM sessions WHERE account_id = :'sam'));
SELECT pg_temp.refused('the only admin cannot delete their own account',
  $$SELECT delete_own_account(pg_temp.t('alex'), 'alex')$$, 'last_admin');
SELECT admin_make_admin(pg_temp.t('alex'), :'kim');
SELECT pg_temp.ok('an admin who is not the only one deletes their own account',
  delete_own_account(pg_temp.t('alex'), 'alex') = :'alex');
SELECT pg_temp.ok('  and the settings they changed keep no reference to them',
  (SELECT changed_by FROM settings WHERE key = 'allow_auto_signup') IS NULL);

ROLLBACK;
