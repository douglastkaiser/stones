"""Deliberate Spark production smoke test; no rating data is seeded or changed.

Creates two disposable anonymous identities and one isolated, finally resigned
QA room. Does not read existing rooms. Credentials remain only in memory. A real
multi-Google-account rating trial is deliberately outside this probe's claims.
"""
import copy
import json
import os
from pathlib import Path
import re
import secrets
import string
import urllib.error
import urllib.request

PROJECT = "stones-9a6a0"
if os.environ.get("STONES_LIVE_TEST") != PROJECT:
    raise RuntimeError("Set STONES_LIVE_TEST=stones-9a6a0 to deliberately run production QA")
SOURCE = (Path(__file__).resolve().parents[1] / "lib/firebase_options.dart").read_text(encoding="utf-8")
KEY = re.search(r"apiKey: '([^']+)'", SOURCE).group(1)
assert f"projectId: '{PROJECT}'" in SOURCE
ROOT = f"https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents"
POOL = "square-5-2-standardTak-open"


def request(url, method="GET", body=None, client=None):
    headers = {"Content-Type": "application/json"}
    if client:
        headers["Authorization"] = "Bearer " + client["idToken"]
    data = None if body is None else json.dumps(body).encode()
    try:
        with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=headers, method=method), timeout=20) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        # Never include identity tokens or raw account payloads in diagnostics.
        return error.code, {}


def accepted(result):
    assert result[0] in (200, 201), f"Unexpected HTTP {result[0]}"
    return result[1]


def denied(result):
    assert result[0] in (401, 403), f"Expected denial; got HTTP {result[0]}"


def value(item):
    if item is None:
        return {"nullValue": None}
    if isinstance(item, bool):
        return {"booleanValue": item}
    if isinstance(item, int):
        return {"integerValue": str(item)}
    if isinstance(item, str):
        return {"stringValue": item}
    if isinstance(item, list):
        return {"arrayValue": {"values": [value(x) for x in item]}}
    return {"mapValue": {"fields": {k: value(v) for k, v in item.items()}}}


def put(path, data, client):
    return request(ROOT + "/" + path, "PATCH", {"fields": value(data)["mapValue"]["fields"]}, client)


filters = [
    {"fieldFilter": {"field": {"fieldPath": "isAi"}, "op": "EQUAL", "value": {"booleanValue": False}}},
    {"fieldFilter": {"field": {"fieldPath": "established"}, "op": "EQUAL", "value": {"booleanValue": True}}},
]
query = {"from": [{"collectionId": "players"}], "where": {"compositeFilter": {"op": "AND", "filters": filters}},
         "orderBy": [{"field": {"fieldPath": "rating"}, "direction": "DESCENDING"}], "limit": 1}
accepted(request(ROOT + f"/ratingPools/{POOL}:runQuery", "POST", {"structuredQuery": query}))
rank_query = copy.deepcopy(query)
rank_query.pop("limit")
rank_query["orderBy"][0]["direction"] = "ASCENDING"
rank_query["where"]["compositeFilter"]["filters"].append(
    {"fieldFilter": {"field": {"fieldPath": "rating"}, "op": "GREATER_THAN", "value": {"integerValue": "1200"}}})
accepted(request(ROOT + f"/ratingPools/{POOL}:runAggregationQuery", "POST", {
    "structuredAggregationQuery": {"structuredQuery": rank_query, "aggregations": [{"alias": "standing", "count": {}}]}}))
print("PASS public leaderboard and aggregate rank queries")
denied(request(ROOT + "/ratingResults"))
denied(request(ROOT + "/aiResultKeys"))
print("PASS private receipt/source enumeration rejected")

clients = []
room_path = None
room = None
try:
    for _ in range(2):
        clients.append(accepted(request("https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" + KEY,
                                        "POST", {"returnSecureToken": True})))
    host, guest = clients
    code = "U" + "".join(secrets.choice(string.ascii_uppercase) for _ in range(6))
    room_path = "matches/" + code
    room = {"version": 1, "code": code, "host": host["localId"], "ratingKey": secrets.token_hex(32),
            "config": {"version": 1, "shape": "square", "size": 3, "starter": "ivory", "profile": "standardTak",
                       "seats": [{"id": "ivory", "control": "localHuman", "level": "easy"},
                                 {"id": "charcoal", "control": "onlineHuman", "level": "easy"}]},
            "owners": {"ivory": host["localId"], "charcoal": None},
            "styles": {"ivory": "morocco", "charcoal": "standard"}, "boardTheme": "morocco",
            "moves": [], "resigned": None, "timedOut": None, "clock": None, "aiRunner": None, "aiLeaseAt": None}
    accepted(put(room_path, room, host))
    room["owners"]["charcoal"] = guest["localId"]
    accepted(put(room_path, room, guest))
    for seat, x, y, client in [("ivory", 2, 2, host), ("charcoal", 0, 0, guest)]:
        room["moves"].append({"seat": seat, "x": x, "y": y, "type": "flat", "direction": None, "drops": []})
        accepted(put(room_path, room, client))
    recovered = accepted(request(ROOT + "/" + room_path, client=guest))
    assert len(recovered["fields"]["moves"]["arrayValue"]["values"]) == 2
    assert recovered["fields"]["ratingKey"]["stringValue"] == room["ratingKey"]
    print("PASS new room key, independent join, opening exchange and cold recovery")
    denied(put(room_path + "/ratingVotes/" + host["localId"], {"ply": 2, "winner": 0, "name": "QA guest"}, host))
    denied(put(f"ratingPools/{POOL}/players/" + host["localId"], {"rating": 9999}, host))
    denied(put("ratingResults/" + room["ratingKey"], {"kind": "human", "pool": POOL}, host))
    print("PASS guests cannot vote, forge totals or create rating receipts")
    room["resigned"] = "ivory"
    accepted(put(room_path, room, host))
    recovered = accepted(request(ROOT + "/" + room_path, client=guest))
    assert recovered["fields"]["resigned"]["stringValue"] == "ivory"
    print("PASS durable room ending; no ratings awarded")
finally:
    # Close an incomplete QA room before removing only the identities this run made.
    if room_path and room and clients and room.get("resigned") is None:
        room["resigned"] = "ivory"
        request(ROOT + "/" + room_path, "PATCH", {"fields": value(room)["mapValue"]["fields"]}, clients[0])
    for client in clients:
        result = request("https://identitytoolkit.googleapis.com/v1/accounts:delete?key=" + KEY,
                         "POST", {"idToken": client["idToken"]})
        assert result[0] == 200, "QA identity cleanup failed"
    if clients:
        print("PASS disposable QA identities removed; no existing user data read or modified")
