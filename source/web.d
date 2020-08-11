module web;

import std;

struct User {
    string username;
    string password;
}

struct SessionStore {
    User[string] store;

    User[] users = [
        User("root", "rootpassword"),
        User("user", "userpassword"),
    ];

    string login(string username, string password) {
        auto maybeUser = users.find!(u => u.username == username).takeOne;

        // No user found with that username
        if (maybeUser.length == 0)
            return "";

        User user = maybeUser[0];

        if (user.password != password)
            return "";

        string sessid = randomUUID().to!string;
        store[sessid] = user;
        return sessid;
    }

    User getUser(string sessid) {
        if (sessid in store)
            return store[sessid];
        return User.init;
    }

    bool logout(string sessid) {
        return store.remove(sessid);
    }
}

alias string[string] CookieJar;

struct WebResponse {
    uint code;
    string content;
    CookieJar cookies;
}

struct WebRequest {
    string content;
    CookieJar cookies;
}

struct WebInterface {
    SessionStore store;

    WebResponse getLogout(WebRequest request) {
        WebResponse response;
        response.code = 200;

        store.logout(request.cookies.get("SESSID", ""));

        return response;
    }

    WebResponse postLogin(WebRequest request) {
        WebResponse response;

        string username;
        string password;

        foreach (field ; request.content.split("&")) {
            string key   = field.split("=")[0];
            string value = field.split("=")[1];

            if (key == "username")
                username = value;
            else if (key == "password")
                password = value;
        }

        string sessid = store.login(username, password);

        if (sessid == "") {
            response.code = 403;
            response.content = "Wrong credentials";
        }
        else {
            response.code = 200;
            response.content = "Logged in as " ~ username;
            response.cookies["SESSID"] = sessid;
        }

        return response;
    }

    WebResponse getAccountPage(WebRequest request) {
        WebResponse response;

        User currentUser = store.getUser(request.cookies.get("SESSID", ""));

        if (currentUser == User.init) {
            response.code = 403;
            response.content = "Unauthorized";
            return response;
        }

        response.code = 200;
        response.content = "Welcome " ~ currentUser.username;
        return response;
    }
}

unittest {
    auto web = WebInterface();

    WebRequest  request;
    WebResponse response;
    CookieJar   cookies;

    response = web.getAccountPage(request);
    assert(response.code == 403);

    request = WebRequest("username=none&password=none", cookies);
    response = web.postLogin(request);
    assert(response.code == 403);

    request = WebRequest("username=user&password=none", cookies);
    response = web.postLogin(request);
    assert(response.code == 403);

    request = WebRequest("username=user&password=userpassword", cookies);
    response = web.postLogin(request);
    assert(response.code == 200);
    assert("SESSID" in response.cookies);
    assert(response.cookies["SESSID"] != "");

    cookies = response.cookies;

    request = WebRequest("", cookies);
    response = web.getAccountPage(request);
    assert(response.code == 200);
    assert(response.content == "Welcome user");

    request = WebRequest("", cookies);
    response = web.getLogout(request);
    assert(response.code == 200);
    assert("SESSID" !in response.cookies);

    cookies = response.cookies;
}
