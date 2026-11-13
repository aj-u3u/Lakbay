"""Recognize a catalog destination the traveler named, without another model call.

The planning chat otherwise depends on the model choosing to select a destination,
and cautious models often just ask follow-up questions. This matches the message
against destination names so a clearly named place ("I like to go to bemwa") is
recognized deterministically.

Matching is conservative:
- Only a destination's *distinctive* words count. Generic words such as "farm", "park"
  or "beach" never match on their own, so "a beach" does not pick a destination.
- Every distinctive word of the name must appear (a one-letter typo is tolerated in
  words of five or more letters).
- A negated request ("I don't want to go to X") is never acted on.
"""

import re
from dataclasses import dataclass

_COMMON_WORDS = frozenset(
    """
    i me my we us you the a an and or of to in on at for with from into about out up
    go going went want wanna like love need would could should please let lets plan
    planning visit visiting see seeing trip travel tour tours stay place places there
    here some any more also just really very good nice best great near around over
    is are was be been this that these those it its if so then than too can will
    day days night nights time week weekend people person people budget peso pesos
    """.split()
)

# Words that appear in many destination names and say little about which one it is;
# this includes region and province words, since a trip "in Davao" names no destination.
_GENERIC_NAME_WORDS = frozenset(
    """
    park parks farm farms beach beaches resort resorts island islands adventure nature
    eco garden gardens mountain mountains mount mt river rivers cave caves falls fall
    waterfall waterfalls view viewpoint center centre museum hotel cafe restaurant
    city town area village bay lake lakes forest trail hills hill peak
    davao philippines philippine national region province del sur norte oriental
    occidental oro
    """.split()
)

_NEGATION = re.compile(
    r"\b(?:don't|dont|do not|not|never|no|avoid|skip|without|except|instead of)\b",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class DestinationMatch:
    destination_id: int
    name: str
    # True when every distinctive word of the name appears in the message.
    strong: bool
    # How many of the name's words (generic ones included) appear in the message.
    overlap: int = 0
    # The distinctive name words that appeared in the message.
    matched: frozenset[str] = frozenset()
    # True when every word of the name (generic ones included) is in the message.
    full: bool = False


def _tokens(text: str) -> list[str]:
    text = text.lower().replace("’", "'")
    text = re.sub(r"'s\b", "", text)
    return re.findall(r"[a-z0-9]+", text)


def _distinctive(name: str) -> list[str]:
    return [
        token
        for token in _tokens(name)
        if len(token) >= 3
        and token not in _GENERIC_NAME_WORDS
        and token not in _COMMON_WORDS
    ]


def _within_one_edit(a: str, b: str) -> bool:
    if abs(len(a) - len(b)) > 1:
        return False
    if len(a) == len(b):
        return sum(x != y for x, y in zip(a, b)) <= 1
    shorter, longer = (a, b) if len(a) < len(b) else (b, a)
    for index in range(len(longer)):
        if longer[:index] + longer[index + 1:] == shorter:
            return True
    return False


def _close(name_word: str, message_word: str) -> bool:
    if name_word == message_word:
        return True
    return (
        len(name_word) >= 5
        and len(message_word) >= 5
        and _within_one_edit(name_word, message_word)
    )


def match_destinations(
    message: str,
    catalog: list[tuple[int, str]],
) -> list[DestinationMatch]:
    """Destinations whose distinctive name words appear in the message.

    A negated request ("I don't want to go to X") matches nothing.
    """
    if _NEGATION.search(message):
        return []
    words = set(_tokens(message))
    matches: list[DestinationMatch] = []
    for destination_id, name in catalog:
        distinctive = _distinctive(name)
        if not distinctive:
            continue
        found = [
            token for token in distinctive if any(_close(token, word) for word in words)
        ]
        if found:
            name_words = [t for t in _tokens(name) if t not in _COMMON_WORDS]
            overlap = sum(1 for t in name_words if any(_close(t, w) for w in words))
            matches.append(
                DestinationMatch(
                    destination_id=destination_id,
                    name=name,
                    strong=len(found) == len(distinctive),
                    overlap=overlap,
                    matched=frozenset(found),
                    full=bool(name_words) and overlap == len(name_words),
                )
            )
    # Most complete matches first; keep catalog order otherwise.
    matches.sort(key=lambda match: (not match.strong, -match.overlap))
    return matches


def pick_single_destination(
    message: str,
    catalog: list[tuple[int, str]],
) -> DestinationMatch | None:
    """The one destination the traveler clearly named, or None when unsure.

    A destination is picked when the message spells out its whole name, or when it is the
    sole full match and no other destination shares any of the matched words. A place name that several destinations share
    ("Samal", "Uraya") is therefore never guessed: those become choices for the
    traveler. Negated requests match nothing.
    """
    matches = match_destinations(message, catalog)
    # Every word of one destination's name was typed: an explicit name, even if other
    # destinations share one of its words ("uraya falls" vs "Uraya's Peak").
    full = [match for match in matches if match.full]
    if len(full) == 1:
        return full[0]
    strong = [match for match in matches if match.strong]
    if len(strong) != 1:
        return None
    winner = strong[0]
    if any(m is not winner and m.matched & winner.matched for m in matches):
        return None
    return winner
