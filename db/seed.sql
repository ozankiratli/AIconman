-- Seeds what an installation needs: the sign-in providers, and the household's
-- settings with their starting values. Run by install/build_schema.sh as the
-- owner role, after every rebuild and on its own; a row already there is left
-- as it is. Takes the starting value of self sign-up, true or false, as the
-- psql variable allow_auto_signup.

INSERT INTO providers (provider) VALUES ('nextcloud')
  ON CONFLICT DO NOTHING;

INSERT INTO settings (key, value) VALUES ('allow_auto_signup', to_jsonb(:'allow_auto_signup'::boolean))
  ON CONFLICT DO NOTHING;
