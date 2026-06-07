import Foundation
import SwiftData

enum MileageCompany: String, CaseIterable, Identifiable {
    case workerBz = "WorkerBz"
    case coolBreeze = "CoolBreeze"
    var id: String { rawValue }
}

@Model
final class MileageRecord {
    var id: UUID
    var date: Date
    var startTime: Date
    var endTime: Date?
    var employeeName: String
    var company: String
    var project: String
    var miles: Double
    var irsRate: Double
    var notes: String

    init(
        date: Date = Date(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        employeeName: String,
        company: String,
        project: String,
        miles: Double,
        irsRate: Double,
        notes: String = ""
    ) {
        self.id = UUID()
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.employeeName = employeeName
        self.company = company
        self.project = project
        self.miles = miles
        self.irsRate = irsRate
        self.notes = notes
    }

    var reimbursement: Double { miles * irsRate }
}
