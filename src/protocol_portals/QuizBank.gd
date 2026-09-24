extends RefCounted
class_name QuizBank

## Loads and validates one protocol quiz bank from disk.
## Pure data: no drawing, no grading, no minting.
## Expected shape: {"protocol": "...", "examiner": "...", "questions": [...]}
## Each question: {"id", "fact_id", "prompt", "options"[3 strings], "correct"(0..2)}

const Signals := preload("res://src/protocol_portals/PortalSignals.gd")

var _protocol: String = ""
var _examiner: String = ""
var _questions: Array[Dictionary] = []


## Reads res://src/protocol_portals/data/quiz_<protocol>.json.
## Returns null and pushes an error when the bank is missing or malformed.
static func load_bank(protocol: String) -> QuizBank:
    var path: String = "res://src/protocol_portals/data/quiz_%s.json" % protocol
    if not FileAccess.file_exists(path):
        push_error("QuizBank: bank file not found: %s" % path)
        return null

    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        push_error("QuizBank: could not open %s (err %d)" % [path, FileAccess.get_open_error()])
        return null
    var text: String = file.get_as_text()
    file.close()

    var parsed: Variant = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY:
        push_error("QuizBank: %s does not contain a JSON object" % path)
        return null
    var data: Dictionary = parsed

    var raw_questions: Variant = data.get("questions", null)
    if typeof(raw_questions) != TYPE_ARRAY:
        push_error("QuizBank: %s is missing a 'questions' array" % path)
        return null
    var question_list: Array = raw_questions
    if question_list.size() != Signals.QUESTION_COUNT:
        push_error("QuizBank: %s has %d questions, expected %d"
            % [path, question_list.size(), Signals.QUESTION_COUNT])
        return null

    var cleaned: Array[Dictionary] = []
    for i in range(question_list.size()):
        var entry: Variant = question_list[i]
        if typeof(entry) != TYPE_DICTIONARY:
            push_error("QuizBank: %s question %d is not an object" % [path, i])
            return null
        var q: Dictionary = entry

        for key in ["id", "fact_id", "prompt"]:
            if typeof(q.get(key, null)) != TYPE_STRING or String(q[key]).is_empty():
                push_error("QuizBank: %s question %d has an invalid '%s'" % [path, i, key])
                return null

        var raw_options: Variant = q.get("options", null)
        if typeof(raw_options) != TYPE_ARRAY:
            push_error("QuizBank: %s question %d has no 'options' array" % [path, i])
            return null
        var option_list: Array = raw_options
        if option_list.size() != 3:
            push_error("QuizBank: %s question %d has %d options, expected 3"
                % [path, i, option_list.size()])
            return null
        for option in option_list:
            if typeof(option) != TYPE_STRING or String(option).is_empty():
                push_error("QuizBank: %s question %d has a non-string option" % [path, i])
                return null

        var raw_correct: Variant = q.get("correct", null)
        if typeof(raw_correct) != TYPE_INT and typeof(raw_correct) != TYPE_FLOAT:
            push_error("QuizBank: %s question %d has no numeric 'correct'" % [path, i])
            return null
        var correct_index: int = int(raw_correct)
        if correct_index < 0 or correct_index > 2:
            push_error("QuizBank: %s question %d 'correct' is out of range 0..2" % [path, i])
            return null

        cleaned.append(q)

    var bank := QuizBank.new()
    bank._protocol = protocol
    bank._examiner = String(data.get("examiner", ""))
    bank._questions = cleaned
    return bank


## Number of questions in the bank (always QUESTION_COUNT when valid).
func size() -> int:
    return _questions.size()


## The question dictionary at `index`, or an empty dictionary with an error.
func question(index: int) -> Dictionary:
    if index < 0 or index >= _questions.size():
        push_error("QuizBank: question index %d out of range" % index)
        return {}
    return _questions[index]


## The correct option index for every question, in order.
func answer_key() -> Array[int]:
    var key: Array[int] = []
    for q in _questions:
        key.append(int(q.get("correct", -1)))
    return key
