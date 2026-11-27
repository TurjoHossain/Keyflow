import Foundation

enum EmojiData {
    static func split(_ text: String) -> [String] {
        return text.map { String($0) }.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    static let categories: [(icon: String, name: String, emojis: [String])] = [
        ("😀", "Smileys", split("😀😃😄😁😆😅😂🤣🥲☺️😊😇🙂🙃😉😌😍🥰😘😗😙😚😋😛😝😜🤪🤨🧐🤓😎🥸🤩🥳😏😒😞😔😟😕🙁☹️😣😖😫😩🥺😢😭😤😠😡🤬🤯😳🥵🥶😱😨😰😥😓🤗🤔🫣🤭🫢🫡🤫🫠🤥😶😐😑😬🙄😯😦😧😮😲🥱😴🤤😪😵🤐🥴🤢🤮🤧😷🤒🤕🤑🤠😈👿👹👺🤡💩👻💀☠️👽👾🤖🎃😺😸😹😻😼😽🙀😿😾")),
        ("👋", "People", split("👋🤚🖐✋🖖👌🤌🤏✌️🤞🫰🤟🤘🤙👈👉👆🖕👇☝️👍👎✊👊🤛🤜👏🙌🫶👐🤲🤝🙏✍️💅🤳💪🦾🦵🦶👂👃🧠👀👅👄💋")),
        ("🐶", "Animals", split("🐶🐱🐭🐹🐰🦊🐻🐼🐨🐯🦁🐮🐷🐸🐵🙈🙉🙊🐔🐧🐦🐤🦆🦅🦉🦇🐺🐗🐴🦄🐝🐛🦋🐌🐞🐜🐢🐍🦎🐙🦑🦐🦀🐠🐟🐬🐳🐋🦈🐊🐅🐆🦓🦍🐘🦛🦏🐪🐫🦒🐃🐄🐎🐖🐏🐑🐐🦌🐕🐩🐈🐓🦃🕊🐇🌵🎄🌲🌳🌴🌱🌿☘️🍀🍁🍂🍃🌺🌻🌹🌷🌼🌸")),
        ("🍔", "Food", split("🍏🍎🍐🍊🍋🍌🍉🍇🍓🫐🍈🍒🍑🥭🍍🥥🥝🍅🍆🥑🥦🥒🌶🌽🥕🥔🍠🥐🍞🥖🧀🥚🍳🥞🧇🥓🥩🍗🍖🌭🍔🍟🍕🥪🌮🌯🥗🍝🍜🍲🍛🍣🍱🥟🍤🍙🍚🍘🍥🍢🍡🍧🍨🍦🥧🧁🍰🎂🍮🍭🍬🍫🍿🍩🍪🥛☕🍵🧃🥤🍶🍺🍻🥂🍷🥃🍸🍹🍾")),
        ("⚽", "Activity", split("⚽🏀🏈⚾🥎🎾🏐🏉🥏🎱🏓🏸🏒🏑🥍🏏⛳🏹🎣🥊🥋🎽🛹⛸🎿🏂🏋️🤸🤺🏇🧘🏄🏊🚴🏆🥇🥈🥉🎖🏅🎗🎫🎟🎪🎭🎨🎬🎤🎧🎼🎹🥁🎷🎺🎸🎻🎲🎯🎳🎮🎰🧩")),
        ("🚗", "Travel", split("🚗🚕🚙🚌🚎🏎🚓🚑🚒🚐🚚🚛🚜🛵🏍🚲🛴🚨🚔🚍🚘🚖🚡🚠🚟🚃🚋🚞🚝🚄🚅🚈🚂🚆🚇🚊🚉✈️🛫🛬🛩💺🚀🛸🚁🛶⛵🚤🛥🛳⛴🚢⚓🚧⛽🚏🚦🚥🗺🗿🗽🗼🏰🏯🏟🎡🎢🎠⛲⛱🏖🏝🏜🌋⛰🏔🗻🏕⛺🏠🏡🏢🏥🏦🏨🏪🏫🌅🌄🌇🌃🌉🌌")),
        ("💡", "Objects", split("⌚📱💻⌨️🖥🖨🖱💽💾📷📹🎥📞☎️📺📻🎙⏰⏳💡🔦🕯💸💵💴💶💷💰💳💎⚖️🔧🔨⚒🛠⛏🔩⚙️💣🔪🛡🔮📿💈🔭🔬💊💉🌡🚽🚿🛁🔑🗝🛋🛏🎁🎈🎉🎊✉️📦📫📝📁📅📆📌📎✂️🔒🔓📚📖")),
        ("❤️", "Symbols", split("❤️🧡💛💚💙💜🖤🤍🤎💔❣️💕💞💓💗💖💘💝💟☮️✝️☪️🕉☸️✡️🔯☯️✅❌❎⭕🚫💯💢♨️🔥✨⭐🌟💫💥💦💤🎵🎶➕➖➗✖️♾‼️⁉️❓❔❕❗〰️©️®️™️🔴🟠🟡🟢🔵🟣⚫⚪🟤🔺🔻🔶🔷🔔🔕🔊🔇📣🏁🚩🎌🏴🏳️🇧🇩🇺🇸🇬🇧🇮🇳🇨🇦🇦🇺"))
    ]

    fileprivate static let keywordPairs: [(String, String)] = [
        ("love", "❤️😍🥰"), ("heart", "❤️💕💖"), ("happy", "😀😊😄"), ("smile", "😊😄🙂"),
        ("laugh", "😂🤣😆"), ("lol", "😂🤣"), ("haha", "😂😆"), ("funny", "😂🤣"),
        ("sad", "😢😞☹️"), ("cry", "😭😢"), ("angry", "😠😡"), ("mad", "😠😡"),
        ("cool", "😎"), ("party", "🥳🎉🎊"), ("birthday", "🎂🎉🥳"), ("congrats", "🎉👏🥳"),
        ("thanks", "🙏😊"), ("thank", "🙏😊"), ("please", "🥺🙏"), ("sorry", "😔🙏"),
        ("ok", "👌👍"), ("okay", "👌👍"), ("yes", "👍✅"), ("no", "🙅👎"),
        ("hi", "👋😊"), ("hello", "👋😊"), ("hey", "👋"), ("bye", "👋"),
        ("goodbye", "👋😢"), ("goodnight", "😴🌙"), ("night", "🌙😴"), ("morning", "🌅☀️"),
        ("sleep", "😴💤"), ("tired", "😴🥱"), ("hungry", "🍔🍕"), ("food", "🍔🍕🍟"),
        ("pizza", "🍕"), ("burger", "🍔"), ("coffee", "☕"), ("tea", "🍵"),
        ("beer", "🍺🍻"), ("cake", "🍰🎂"), ("fire", "🔥"), ("hot", "🥵🔥"),
        ("cold", "🥶"), ("snow", "❄️⛄"), ("rain", "🌧☔"), ("sun", "☀️😎"),
        ("moon", "🌙"), ("star", "⭐🌟"), ("money", "💰💸"), ("cash", "💵💰"),
        ("work", "💼💻"), ("home", "🏠"), ("car", "🚗"), ("travel", "✈️🧳"),
        ("plane", "✈️"), ("beach", "🏖🌴"), ("music", "🎵🎶"), ("song", "🎵🎤"),
        ("dance", "💃🕺"), ("game", "🎮"), ("football", "⚽🏈"), ("soccer", "⚽"),
        ("basketball", "🏀"), ("cricket", "🏏"), ("win", "🏆🥇"), ("winner", "🏆"),
        ("trophy", "🏆"), ("dog", "🐶"), ("cat", "🐱"), ("bird", "🐦"),
        ("fish", "🐟"), ("flower", "🌸🌹"), ("tree", "🌳"), ("kiss", "😘💋"),
        ("hug", "🤗"), ("pray", "🙏"), ("think", "🤔"), ("thinking", "🤔"),
        ("wow", "😮🤩"), ("omg", "😱😮"), ("shock", "😱"), ("scared", "😨😱"),
        ("sick", "🤒🤢"), ("phone", "📱"), ("call", "📞"), ("laptop", "💻"),
        ("book", "📖📚"), ("study", "📚✏️"), ("school", "🏫"), ("gift", "🎁"),
        ("idea", "💡"), ("light", "💡"), ("eyes", "👀"), ("clap", "👏"),
        ("strong", "💪"), ("peace", "✌️"), ("bangladesh", "🇧🇩"), ("usa", "🇺🇸"),
        ("india", "🇮🇳"), ("bored", "😑🥱"), ("excited", "🤩🎉"), ("proud", "🥹👏")
    ]

    static let keywords: [String: String] = {
        var table: [String: String] = [:]
        for (key, value) in EmojiData.keywordPairs {
            table[key] = value
        }
        return table
    }()

    /// One emoji to offer in the suggestion bar for a typed word.
    static func suggestion(for word: String) -> String? {
        let w = word.lowercased()
        guard w.count >= 2 else { return nil }
        var candidates = [w]
        if w.hasSuffix("s") && w.count > 3 { candidates.append(String(w.dropLast())) }
        for c in candidates {
            if let value = keywords[c], let first = split(value).first {
                return first
            }
        }
        return nil
    }

    /// Emoji matching a search query (keywords and category names).
    static func search(_ query: String) -> [String] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        var result: [String] = []
        var seen = Set<String>()
        func add(_ list: [String]) {
            for e in list where !seen.contains(e) {
                seen.insert(e)
                result.append(e)
            }
        }
        for key in keywords.keys.sorted() where key.contains(q) {
            if let value = keywords[key] { add(split(value)) }
        }
        for category in categories where category.name.lowercased().contains(q) {
            add(category.emojis)
        }
        return result
    }
}
