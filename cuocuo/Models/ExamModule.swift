import Foundation

enum ExamModule: String, Codable, CaseIterable, Identifiable, Hashable {
    case verbal
    case judgment
    case quantitative
    case data

    var id: String { rawValue }

    var title: String {
        switch self {
        case .verbal: "言语理解"
        case .judgment: "判断推理"
        case .quantitative: "数量关系"
        case .data: "资料分析"
        }
    }

    var fullName: String {
        switch self {
        case .verbal: "言语理解与表达"
        case .judgment: "判断推理"
        case .quantitative: "数量关系"
        case .data: "资料分析"
        }
    }

    var symbol: String {
        switch self {
        case .verbal: "text.book.closed"
        case .judgment: "point.topleft.down.to.point.bottomright.curvepath"
        case .quantitative: "function"
        case .data: "chart.bar.xaxis"
        }
    }

    var subtypes: [String] {
        switch self {
        case .verbal: ["逻辑填空", "片段阅读", "语句表达"]
        case .judgment: ["图形推理", "定义判断", "类比推理", "逻辑判断"]
        case .quantitative: ["数学运算", "数字推理"]
        case .data: ["文字资料", "表格资料", "图形资料", "综合资料"]
        }
    }
}

enum Mastery: String, Codable, CaseIterable, Identifiable, Hashable {
    case unmastered
    case mastered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unmastered: "未掌握"
        case .mastered: "已掌握"
        }
    }

    var symbol: String {
        switch self {
        case .unmastered: "circle"
        case .mastered: "checkmark.circle"
        }
    }

    var toggledTitle: String {
        switch self {
        case .unmastered: "标为已掌握"
        case .mastered: "标为未掌握"
        }
    }

    var toggledSymbol: String {
        switch self {
        case .unmastered: "checkmark.circle"
        case .mastered: "circle"
        }
    }
}

enum PageKind: String, Codable, Hashable {
    case question
    case analysis

    var title: String {
        switch self {
        case .question: "题目"
        case .analysis: "错因"
        }
    }
}

enum LibrarySection: Hashable, Identifiable {
    case all
    case module(ExamModule)

    static let sidebar: [LibrarySection] = [.all] + ExamModule.allCases.map(LibrarySection.module)

    var id: String {
        switch self {
        case .all: "all"
        case .module(let module): module.rawValue
        }
    }

    var module: ExamModule? {
        if case .module(let module) = self { module } else { nil }
    }

    var title: String {
        switch self {
        case .all: "全部错题"
        case .module(let module): module.title
        }
    }

    var subtitle: String {
        switch self {
        case .all: "四个模块"
        case .module(let module): module.fullName
        }
    }

    var symbol: String {
        switch self {
        case .all: "square.grid.2x2"
        case .module(let module): module.symbol
        }
    }
}

enum CauseTagLibrary {
    static let common = ["审题偏差", "知识点盲区", "粗心", "时间不够", "选项比较失误"]

    static func specific(_ module: ExamModule) -> [String] {
        switch module {
        case .verbal:
            ["词语辨析不清", "语境把握错", "主旨概括偏", "细节对应错"]
        case .judgment:
            ["图形规律未识别", "定义要点遗漏", "类比关系判错", "推理形式错误", "加强削弱方向反了"]
        case .quantitative:
            ["公式用错", "计算错误", "条件转化错", "未作代入排除"]
        case .data:
            ["读数或单位错误", "公式用错", "估算比较失误", "时间范围看错"]
        }
    }

    static func presets(for module: ExamModule) -> [String] {
        common + specific(module)
    }

    static func isBuiltIn(_ tag: String) -> Bool {
        if common.contains(tag) { return true }
        return ExamModule.allCases.contains { specific($0).contains(tag) }
    }
}
