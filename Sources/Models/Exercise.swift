import Foundation

struct ExerciseDefinition: Codable, Identifiable, Hashable {
    var id: String
    var nameZh: String
    var nameEn: String?
    var isBuiltin: Bool
    var primaryMuscles: [MuscleGroup]
    var secondaryMuscles: [MuscleGroup]
    var equipment: EquipmentType
    var laterality: Laterality
    var isCompound: Bool
    var instructions: [String]
    var imageAssetNames: [String]
    var videoURL: URL?
    var isArchived: Bool
    var incrementKgOverride: Double?
    var restSecondsOverride: Int?
    var repRangeMinOverride: Int?
    var repRangeMaxOverride: Int?

    init(id: String = UUID().uuidString, nameZh: String, nameEn: String? = nil, isBuiltin: Bool = false,
         primaryMuscles: [MuscleGroup], secondaryMuscles: [MuscleGroup] = [], equipment: EquipmentType,
         laterality: Laterality = .bilateral, isCompound: Bool = false, instructions: [String] = [],
         imageAssetNames: [String] = [], videoURL: URL? = nil, isArchived: Bool = false,
         incrementKgOverride: Double? = nil, restSecondsOverride: Int? = nil,
         repRangeMinOverride: Int? = nil, repRangeMaxOverride: Int? = nil) {
        self.id = id
        self.nameZh = nameZh
        self.nameEn = nameEn
        self.isBuiltin = isBuiltin
        self.primaryMuscles = primaryMuscles
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.laterality = laterality
        self.isCompound = isCompound
        self.instructions = instructions
        self.imageAssetNames = imageAssetNames
        self.videoURL = videoURL
        self.isArchived = isArchived
        self.incrementKgOverride = incrementKgOverride
        self.restSecondsOverride = restSecondsOverride
        self.repRangeMinOverride = repRangeMinOverride
        self.repRangeMaxOverride = repRangeMaxOverride
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        nameZh = try c.decode(String.self, forKey: .nameZh)
        nameEn = try c.decodeIfPresent(String.self, forKey: .nameEn)
        isBuiltin = try c.decodeIfPresent(Bool.self, forKey: .isBuiltin) ?? true
        primaryMuscles = try c.decode([MuscleGroup].self, forKey: .primaryMuscles)
        secondaryMuscles = try c.decodeIfPresent([MuscleGroup].self, forKey: .secondaryMuscles) ?? []
        equipment = try c.decode(EquipmentType.self, forKey: .equipment)
        laterality = try c.decodeIfPresent(Laterality.self, forKey: .laterality) ?? .bilateral
        isCompound = try c.decodeIfPresent(Bool.self, forKey: .isCompound) ?? false
        instructions = try c.decodeIfPresent([String].self, forKey: .instructions) ?? []
        imageAssetNames = try c.decodeIfPresent([String].self, forKey: .imageAssetNames) ?? []
        videoURL = try c.decodeIfPresent(URL.self, forKey: .videoURL)
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        incrementKgOverride = try c.decodeIfPresent(Double.self, forKey: .incrementKgOverride)
        restSecondsOverride = try c.decodeIfPresent(Int.self, forKey: .restSecondsOverride)
        repRangeMinOverride = try c.decodeIfPresent(Int.self, forKey: .repRangeMinOverride)
        repRangeMaxOverride = try c.decodeIfPresent(Int.self, forKey: .repRangeMaxOverride)
    }

    var primaryMuscle: MuscleGroup { primaryMuscles.first ?? .chest }
    var defaultIncrementKg: Double { incrementKgOverride ?? Increment.defaultKg(equipment: equipment, muscle: primaryMuscle) }
    var defaultRestSeconds: Int { restSecondsOverride ?? (isCompound ? Limits.restCompound : Limits.restIsolation) }
    var defaultRepRange: ClosedRange<Int> {
        if let lo = repRangeMinOverride, let hi = repRangeMaxOverride, lo < hi { return lo...hi }
        return isCompound && primaryMuscle.isLarge ? Limits.repRangeCompound : Limits.repRangeIsolation
    }
    var pinyinInitials: String { Pinyin.initials(nameZh) }
    var volumeMultiplier: Double { equipment == .dumbbell ? 2 : 1 }
    var isPerHand: Bool { equipment == .dumbbell }

    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if q.isEmpty { return true }
        if nameZh.lowercased().contains(q) { return true }
        if let en = nameEn, en.lowercased().contains(q) { return true }
        return pinyinInitials.contains(q)
    }
}

struct LibraryState: Codable {
    var custom: [ExerciseDefinition] = []
    var archivedIds: Set<String> = []
}

struct ExerciseLibrary {
    private(set) var builtin: [ExerciseDefinition]
    var state: LibraryState

    init(builtin: [ExerciseDefinition], state: LibraryState = LibraryState()) {
        self.builtin = builtin
        self.state = state
    }

    static func loadBuiltin(from url: URL) throws -> [ExerciseDefinition] {
        try JSONDecoder().decode([ExerciseDefinition].self, from: Data(contentsOf: url))
    }

    var all: [ExerciseDefinition] {
        builtin.map { def in
            var d = def
            d.isArchived = state.archivedIds.contains(def.id)
            return d
        } + state.custom
    }

    var selectable: [ExerciseDefinition] { all.filter { !$0.isArchived } }

    subscript(id: String) -> ExerciseDefinition? {
        if let c = state.custom.first(where: { $0.id == id }) { return c }
        guard var b = builtin.first(where: { $0.id == id }) else { return nil }
        b.isArchived = state.archivedIds.contains(id)
        return b
    }

    func search(_ query: String, muscle: MuscleGroup? = nil, equipment: EquipmentType? = nil) -> [ExerciseDefinition] {
        selectable.filter { def in
            def.matches(query)
                && (muscle == nil || def.primaryMuscles.contains(muscle!))
                && (equipment == nil || def.equipment == equipment!)
        }
    }

    func alternatives(for exercise: ExerciseDefinition, trainedIds: Set<String>, limit: Int = 5) -> [ExerciseDefinition] {
        let base = Set(exercise.primaryMuscles)
        func score(_ d: ExerciseDefinition) -> Int {
            var s = 0
            if d.equipment != exercise.equipment { s += 100 }
            s += Set(d.primaryMuscles).intersection(base).count * 10
            if trainedIds.contains(d.id) { s += 5 }
            if d.isCompound == exercise.isCompound { s += 1 }
            return s
        }
        return selectable
            .filter { $0.id != exercise.id && !Set($0.primaryMuscles).isDisjoint(with: base) }
            .sorted { score($0) > score($1) }
            .prefix(limit)
            .map { $0 }
    }

    mutating func add(_ custom: ExerciseDefinition) {
        var c = custom
        c.isBuiltin = false
        state.custom.append(c)
    }

    mutating func update(_ custom: ExerciseDefinition) {
        guard let i = state.custom.firstIndex(where: { $0.id == custom.id }) else { return }
        state.custom[i] = custom
    }

    mutating func setArchived(_ id: String, _ archived: Bool) {
        if let i = state.custom.firstIndex(where: { $0.id == id }) {
            state.custom[i].isArchived = archived
        } else if archived {
            state.archivedIds.insert(id)
        } else {
            state.archivedIds.remove(id)
        }
    }
}

enum Pinyin {
    private static var cache: [String: String] = [:]

    static func initials(_ text: String) -> String {
        if let hit = cache[text] { return hit }
        let latin = text.applyingTransform(.mandarinToLatin, reverse: false) ?? text
        let plain = latin.applyingTransform(.stripDiacritics, reverse: false) ?? latin
        let result = plain.split(separator: " ").compactMap { $0.first.map(String.init) }.joined().lowercased()
        cache[text] = result
        return result
    }
}
