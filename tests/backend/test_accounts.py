"""Tests of the account endpoints, against the database the configuration in
AICONMAN_CONFIG_DIR names, rebuilt before each test. The application runs in
the test's own process, reached at server.public_url, with that site's Origin
header; each person is a client of their own, keeping their own cookie. Every
password is made up.

Most tests lower scrypt's cost to keep the run short: a salt string carries the
cost it was made with, so hashing and checking go the same way.
test_the_database_keeps_only_a_scrypt_hash runs at the real cost.

    AICONMAN_CONFIG_DIR=.tmp/scratch/config .venv/bin/python -m unittest discover -s tests/backend -p 'test_accounts.py'
"""

import asyncio
import dataclasses
import unicodedata
import unittest
from unittest import mock
from urllib.parse import urlsplit

import httpx

import scratch
from aiconman import config as configuration
from aiconman import passwords
from aiconman.app import create_app

STRONG = "Correct-Horse-42-Battery!"
OTHER = "Another-Pass-77-Word!!"
THIRD = "Third-Secret-90-Phrase??"


def setUpModule():
    scratch.require()


class AccountsTest(unittest.IsolatedAsyncioTestCase):
    real_cost = False

    def setUp(self):
        scratch.rebuild()
        if not self.real_cost:
            patcher = mock.patch.object(passwords, "N", 2**10)
            patcher.start()
            self.addCleanup(patcher.stop)

    async def asyncSetUp(self):
        self.config = configuration.load()
        self.app = create_app(self.config)
        public = urlsplit(self.config.server.public_url)
        self.origin = f"{public.scheme}://{public.netloc}"

    def browser(self, origin: str | None = None, app=None) -> httpx.AsyncClient:
        """A client of its own, like one person's browser, sending ORIGIN, or
        the site's own, as its Origin header."""
        client = httpx.AsyncClient(
            transport=httpx.ASGITransport(app=app or self.app), base_url=self.config.server.public_url,
            headers={"Origin": origin or self.origin},
        )
        self.addAsyncCleanup(client.aclose)
        return client

    async def signed_up(self, username: str, password: str = STRONG) -> httpx.AsyncClient:
        """A client that has signed up as USERNAME."""
        client = self.browser()
        response = await client.post("/api/auth/sign-up", json={"username": username, "password": password})
        self.assertEqual(response.status_code, 200, response.text)
        return client

    def assertRefused(self, response: httpx.Response, status: int, key: str):
        self.assertEqual((response.status_code, response.json().get("error")), (status, key), response.text)

    # Signing up and in ---------------------------------------------------------

    async def test_the_options_say_what_is_on(self):
        response = await self.browser().get("/api/auth/options")
        self.assertEqual(response.json(), {"password_login": True, "nextcloud_login": False,
                                           "sign_up_open": True})

    async def test_a_weak_password_is_refused_with_the_rules_it_misses(self):
        response = await self.browser().post("/api/auth/sign-up", json={"username": "alex", "password": "short"})
        self.assertRefused(response, 400, "password_weak")
        self.assertEqual(response.json()["rules"], ["length", "uppercase", "digits", "symbols"])

    async def test_the_first_account_is_the_admin_and_the_next_a_member(self):
        alex = await self.signed_up("alex")
        sam = await self.signed_up("sam")
        self.assertEqual((await alex.get("/api/me")).json()["role"], "admin")
        self.assertEqual((await sam.get("/api/me")).json()["role"], "member")

    async def test_the_session_cookie(self):
        response = await self.browser().post("/api/auth/sign-up", json={"username": "alex", "password": STRONG})
        cookie = response.headers["set-cookie"]
        self.assertTrue(cookie.startswith(f"{self.config.auth.cookie_name}="), cookie)
        for attribute in ("HttpOnly", "Path=/", "SameSite=strict",
                          f"Max-Age={self.config.auth.absolute_hours * 3600}"):
            self.assertIn(attribute, cookie)
        self.assertEqual("Secure" in cookie, self.config.auth.cookie_secure)

    async def test_signing_in_and_out(self):
        await self.signed_up("alex")
        browser = self.browser()
        self.assertRefused(await browser.post("/api/auth/sign-in", json={"username": "alex", "password": OTHER}),
                           401, "wrong_credentials")
        self.assertRefused(await browser.post("/api/auth/sign-in", json={"username": "nobody", "password": STRONG}),
                           401, "wrong_credentials")
        response = await browser.post("/api/auth/sign-in", json={"username": "alex", "password": STRONG})
        self.assertEqual(response.json()["username"], "alex")
        self.assertEqual((await browser.get("/api/me")).status_code, 200)
        response = await browser.post("/api/auth/sign-out")
        self.assertIn("Max-Age=0", response.headers["set-cookie"])
        self.assertRefused(await browser.get("/api/me"), 401, "session_invalid")

    async def test_a_password_typed_in_another_unicode_form_signs_in(self):
        composed = "Caf\u00e9-Strong-Pass-12!!"
        await self.signed_up("alex", composed)
        decomposed = unicodedata.normalize("NFD", composed)
        self.assertNotEqual(composed, decomposed)
        response = await self.browser().post("/api/auth/sign-in", json={"username": "alex", "password": decomposed})
        self.assertEqual(response.status_code, 200, response.text)

    async def test_whitespace_at_either_end_of_a_password_is_removed(self):
        await self.signed_up("alex", f"  {STRONG}\t\n")
        for typed in (STRONG, f" {STRONG} "):
            response = await self.browser().post("/api/auth/sign-in", json={"username": "alex", "password": typed})
            self.assertEqual(response.status_code, 200, repr(typed))

    async def test_a_space_inside_a_password_is_refused(self):
        response = await self.browser().post("/api/auth/sign-up",
                                             json={"username": "alex", "password": "Correct Horse-42-Battery!"})
        self.assertRefused(response, 400, "password_weak")
        self.assertEqual(response.json()["rules"], ["spaces"])

    async def test_digits_do_not_count_as_symbols(self):
        response = await self.browser().post("/api/auth/sign-up",
                                             json={"username": "alex", "password": "CorrectHorse4242Battery"})
        self.assertRefused(response, 400, "password_weak")
        self.assertEqual(response.json()["rules"], ["symbols"])

    async def test_no_cookie_or_an_unknown_one(self):
        self.assertRefused(await self.browser().get("/api/me"), 401, "session_invalid")
        browser = self.browser()
        browser.cookies.set(self.config.auth.cookie_name, "made-up-token")
        self.assertRefused(await browser.get("/api/me"), 401, "session_invalid")

    async def test_a_change_from_a_page_of_another_site_is_refused(self):
        await self.signed_up("alex")
        elsewhere = self.browser(origin="https://elsewhere.example")
        self.assertRefused(await elsewhere.post("/api/auth/sign-in", json={"username": "alex", "password": STRONG}),
                           403, "origin_refused")
        self.assertEqual((await elsewhere.get("/api/auth/options")).status_code, 200)
        no_origin = httpx.AsyncClient(transport=httpx.ASGITransport(app=self.app),
                                      base_url=self.config.server.public_url)
        self.addAsyncCleanup(no_origin.aclose)
        response = await no_origin.post("/api/auth/sign-in", json={"username": "alex", "password": STRONG})
        self.assertEqual(response.status_code, 200, response.text)

    async def test_a_malformed_request_names_its_fields(self):
        response = await self.browser().post("/api/auth/sign-in", json={})
        self.assertRefused(response, 400, "request_invalid")
        self.assertEqual(response.json()["fields"], ["password", "username"])

    async def test_password_sign_in_switched_off(self):
        off = dataclasses.replace(self.config, auth=dataclasses.replace(self.config.auth, password_login=False))
        browser = self.browser(app=create_app(off))
        self.assertRefused(await browser.post("/api/auth/sign-up", json={"username": "alex", "password": STRONG}),
                           403, "password_login_off")
        self.assertRefused(await browser.post("/api/auth/sign-in", json={"username": "alex", "password": STRONG}),
                           403, "password_login_off")

    # One's own account -------------------------------------------------------------

    async def test_signing_out_everywhere_else(self):
        alex = await self.signed_up("alex")
        laptop = self.browser()
        await laptop.post("/api/auth/sign-in", json={"username": "alex", "password": STRONG})
        self.assertEqual((await alex.post("/api/me/sign-out-others")).json(), {"revoked": 1})
        self.assertRefused(await laptop.get("/api/me"), 401, "session_invalid")
        self.assertEqual((await alex.get("/api/me")).status_code, 200)

    async def test_changing_ones_name_display_name_and_theme(self):
        alex = await self.signed_up("alex")
        await self.signed_up("sam")
        self.assertEqual((await alex.put("/api/me/username", json={"username": "alexa"})).json()["username"], "alexa")
        self.assertRefused(await alex.put("/api/me/username", json={"username": "sam"}), 409, "username_taken")
        self.assertRefused(await alex.put("/api/me/username", json={"username": "Alexa"}), 400, "username_invalid")
        response = await alex.put("/api/me/display-name", json={"display_name": "Alexa A."})
        self.assertEqual(response.json()["display_name"], "Alexa A.")
        self.assertEqual((await alex.put("/api/me/theme", json={"theme": "dark-hc"})).json()["theme"], "dark-hc")
        self.assertRefused(await alex.put("/api/me/theme", json={"theme": "blue"}), 400, "theme_invalid")

    async def test_changing_ones_password(self):
        alex = await self.signed_up("alex")
        phone = self.browser()
        await phone.post("/api/auth/sign-in", json={"username": "alex", "password": STRONG})
        self.assertRefused(await alex.put("/api/me/password", json={"current_password": OTHER, "new_password": THIRD}),
                           400, "current_password_wrong")
        self.assertRefused(await alex.put("/api/me/password", json={"new_password": THIRD}),
                           400, "current_password_wrong")
        self.assertRefused(await alex.put("/api/me/password", json={"current_password": STRONG, "new_password": "weak"}),
                           400, "password_weak")
        response = await alex.put("/api/me/password", json={"current_password": STRONG, "new_password": THIRD})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertRefused(await phone.get("/api/me"), 401, "session_invalid")
        self.assertEqual((await alex.get("/api/me")).status_code, 200)
        fresh = self.browser()
        self.assertRefused(await fresh.post("/api/auth/sign-in", json={"username": "alex", "password": STRONG}),
                           401, "wrong_credentials")
        self.assertEqual((await fresh.post("/api/auth/sign-in", json={"username": "alex", "password": THIRD})).status_code, 200)

    async def test_deleting_ones_own_account_and_folder(self):
        await self.signed_up("alex")
        sam = await self.signed_up("sam")
        sam_id = (await sam.get("/api/me")).json()["account_id"]
        folder = self.config.storage.root_path / sam_id
        (folder / "images").mkdir(parents=True)
        (folder / "images" / "x.png").write_bytes(b"made up")
        self.assertRefused(await sam.post("/api/me/delete", json={"username": "alex"}), 400, "confirmation_mismatch")
        response = await sam.post("/api/me/delete", json={"username": "sam"})
        self.assertEqual(response.json(), {"deleted": sam_id, "folder_removed": True})
        self.assertFalse(folder.exists())
        self.assertRefused(await sam.get("/api/me"), 401, "session_invalid")

    # Administration -------------------------------------------------------------------

    async def test_a_member_cannot_administer(self):
        await self.signed_up("alex")
        sam = await self.signed_up("sam")
        self.assertRefused(await sam.get("/api/admin/accounts"), 403, "not_admin")
        self.assertRefused(await sam.get("/api/admin/settings"), 403, "not_admin")
        self.assertRefused(await sam.post("/api/admin/accounts", json={"username": "kim", "password": STRONG}),
                           403, "not_admin")

    async def test_an_account_the_admin_creates_must_change_its_password(self):
        alex = await self.signed_up("alex")
        self.assertRefused(await alex.post("/api/admin/accounts", json={"username": "kim", "password": "weak"}),
                           400, "password_weak")
        response = await alex.post("/api/admin/accounts", json={"username": "kim", "password": OTHER})
        kim_id = response.json()["account_id"]
        self.assertEqual([a["username"] for a in (await alex.get("/api/admin/accounts")).json()], ["alex", "kim"])
        kim = self.browser()
        await kim.post("/api/auth/sign-in", json={"username": "kim", "password": OTHER})
        me = (await kim.get("/api/me")).json()
        self.assertEqual((me["account_id"], me["must_change_password"]), (kim_id, True))
        self.assertRefused(await kim.put("/api/me/theme", json={"theme": "dark"}), 403, "password_change_required")
        response = await kim.put("/api/me/password", json={"new_password": THIRD})
        self.assertFalse(response.json()["must_change_password"])
        self.assertEqual((await kim.put("/api/me/theme", json={"theme": "dark"})).status_code, 200)

    async def test_the_admin_resets_a_password(self):
        alex = await self.signed_up("alex")
        kim = await self.signed_up("kim", OTHER)
        kim_id = (await kim.get("/api/me")).json()["account_id"]
        response = await alex.post(f"/api/admin/accounts/{kim_id}/reset-password", json={"password": THIRD})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertRefused(await kim.get("/api/me"), 401, "session_invalid")
        fresh = self.browser()
        self.assertRefused(await fresh.post("/api/auth/sign-in", json={"username": "kim", "password": OTHER}),
                           401, "wrong_credentials")
        await fresh.post("/api/auth/sign-in", json={"username": "kim", "password": THIRD})
        self.assertTrue((await fresh.get("/api/me")).json()["must_change_password"])

    async def test_the_admin_closes_and_opens_sign_up(self):
        alex = await self.signed_up("alex")
        response = await alex.put("/api/admin/settings/allow_auto_signup", json={"value": False})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertFalse((await self.browser().get("/api/auth/options")).json()["sign_up_open"])
        response = await self.browser().post("/api/auth/sign-up", json={"username": "sam", "password": STRONG})
        self.assertRefused(response, 403, "sign_up_closed")
        settings = (await alex.get("/api/admin/settings")).json()
        self.assertEqual([(s["key"], s["value"], s["changed_by"]) for s in settings],
                         [("allow_auto_signup", False, "alex")])
        self.assertRefused(await alex.put("/api/admin/settings/allow_auto_signup", json={"value": "no"}),
                           400, "setting_invalid")
        self.assertRefused(await alex.put("/api/admin/settings/no_such_setting", json={"value": True}),
                           400, "setting_unknown")

    async def test_the_admin_role(self):
        alex = await self.signed_up("alex")
        sam = await self.signed_up("sam")
        sam_id = (await sam.get("/api/me")).json()["account_id"]
        self.assertEqual((await alex.post(f"/api/admin/accounts/{sam_id}/make-admin")).status_code, 200)
        self.assertEqual((await sam.get("/api/admin/accounts")).status_code, 200)
        self.assertEqual((await sam.post("/api/me/give-up-admin")).json()["role"], "member")
        self.assertRefused(await alex.post("/api/me/give-up-admin"), 400, "last_admin")
        self.assertRefused(await alex.post("/api/admin/accounts/zzzzzzzz/make-admin"), 404, "no_such_account")

    async def test_the_admin_deactivates_and_reactivates(self):
        alex = await self.signed_up("alex")
        sam = await self.signed_up("sam")
        sam_id = (await sam.get("/api/me")).json()["account_id"]
        alex_id = (await alex.get("/api/me")).json()["account_id"]
        await alex.put(f"/api/admin/accounts/{sam_id}/active", json={"active": False})
        self.assertRefused(await sam.get("/api/me"), 401, "session_invalid")
        response = await self.browser().post("/api/auth/sign-in", json={"username": "sam", "password": STRONG})
        self.assertRefused(response, 403, "deactivated")
        await alex.put(f"/api/admin/accounts/{sam_id}/active", json={"active": True})
        response = await self.browser().post("/api/auth/sign-in", json={"username": "sam", "password": STRONG})
        self.assertEqual(response.status_code, 200, response.text)
        self.assertRefused(await alex.put(f"/api/admin/accounts/{alex_id}/active", json={"active": False}),
                           400, "not_self")

    async def test_the_admin_deletes_an_account_and_its_folder(self):
        alex = await self.signed_up("alex")
        sam = await self.signed_up("sam")
        sam_id = (await sam.get("/api/me")).json()["account_id"]
        folder = self.config.storage.root_path / sam_id
        folder.mkdir(parents=True)
        (folder / "notes.txt").write_text("made up")
        response = await alex.delete(f"/api/admin/accounts/{sam_id}")
        self.assertEqual(response.json(), {"deleted": sam_id, "folder_removed": True})
        self.assertFalse(folder.exists())
        self.assertRefused(await sam.get("/api/me"), 401, "session_invalid")


class RealCostTest(AccountsTest):
    real_cost = True

    async def test_the_database_keeps_only_a_scrypt_hash(self):
        await self.signed_up("alex")
        salt, hash_ = scratch.owner_query("SELECT password_salt, password_hash FROM accounts WHERE username = 'alex'")[0]
        self.assertTrue(salt.startswith("scrypt$n=131072,r=8,p=1$"), salt)
        self.assertEqual(len(hash_), 32)
        self.assertEqual(bytes(hash_), await asyncio.to_thread(passwords.hash_password, STRONG, salt))
        self.assertNotIn(STRONG.encode(), bytes(hash_) + salt.encode())


def load_tests(loader, tests, pattern):
    """AccountsTest's tests, and only the real-cost test of RealCostTest, which
    would otherwise run them all again."""
    suite = unittest.TestSuite()
    suite.addTests(loader.loadTestsFromTestCase(AccountsTest))
    suite.addTest(RealCostTest("test_the_database_keeps_only_a_scrypt_hash"))
    return suite


if __name__ == "__main__":
    unittest.main()
