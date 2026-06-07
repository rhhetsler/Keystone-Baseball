import SwiftUI
import SwiftData

// MARK: - IRS Rate Manager

final class IRSRateManager: ObservableObject {
    static let shared = IRSRateManager()

    @Published var rate: Double {
        didSet { UserDefaults.standard.set(rate, forKey: "mileage.irsRate") }
    }
    @Published var effectiveDate: Date {
        didSet { UserDefaults.standard.set(effectiveDate, forKey: "mileage.irsEffectiveDate") }
    }
    @Published var lastUpdated: Date {
        didSet { UserDefaults.standard.set(lastUpdated, forKey: "mileage.irsLastUpdated") }
    }

    private init() {
        let d = UserDefaults.standard
        let saved = d.double(forKey: "mileage.irsRate")
        rate = saved > 0 ? saved : 0.70
        effectiveDate = (d.object(forKey: "mileage.irsEffectiveDate") as? Date)
            ?? Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        lastUpdated = (d.object(forKey: "mileage.irsLastUpdated") as? Date) ?? Date()
    }

    func update(rate newRate: Double, effectiveDate newDate: Date) {
        rate = newRate
        effectiveDate = newDate
        lastUpdated = Date()
    }
}

// MARK: - Root View

struct MileageRootView: View {
    @StateObject private var rateManager = IRSRateManager.shared

    var body: some View {
        NavigationStack {
            MileageListView()
        }
        .environmentObject(rateManager)
    }
}

// MARK: - List View

struct MileageListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var rateManager: IRSRateManager
    @Query(sort: \MileageRecord.date, order: .reverse) private var records: [MileageRecord]

    @State private var showAddSheet = false
    @State private var showRateSettings = false
    @State private var selectedRecord: MileageRecord?
    @State private var recordToDelete: MileageRecord?
    @State private var showDeleteConfirm = false
    @State private var filterCompany = "All"

    private let companies = ["All"] + MileageCompany.allCases.map(\.rawValue)

    private var filtered: [MileageRecord] {
        filterCompany == "All" ? records : records.filter { $0.company == filterCompany }
    }

    private var totalMiles: Double { filtered.reduce(0) { $0 + $1.miles } }
    private var totalReimbursement: Double { filtered.reduce(0) { $0 + $1.reimbursement } }

    var body: some View {
        VStack(spacing: 0) {
            summaryBar
            rateBar
            filterBar

            if filtered.isEmpty {
                ContentUnavailableView(
                    "No Mileage Records",
                    systemImage: "car.fill",
                    description: Text("Tap + to log your first trip.")
                )
            } else {
                List {
                    ForEach(filtered) { record in
                        MileageRowView(record: record)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedRecord = record }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    recordToDelete = record
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Mileage Tracker")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showRateSettings = true } label: {
                    Image(systemName: "gear")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddMileageView().environmentObject(rateManager)
        }
        .sheet(item: $selectedRecord) { record in
            AddMileageView(existing: record).environmentObject(rateManager)
        }
        .sheet(isPresented: $showRateSettings) {
            IRSRateSettingsView().environmentObject(rateManager)
        }
        .confirmationDialog("Delete this record?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let r = recordToDelete { modelContext.delete(r) }
            }
        }
    }

    private var summaryBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total Miles").font(.caption).foregroundStyle(.secondary)
                Text(String(format: "%.1f mi", totalMiles)).font(.title2.bold())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Est. Reimbursement").font(.caption).foregroundStyle(.secondary)
                Text(totalReimbursement, format: .currency(code: "USD"))
                    .font(.title2.bold()).foregroundStyle(.green)
            }
        }
        .padding(.horizontal).padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    private var rateBar: some View {
        HStack(spacing: 4) {
            Image(systemName: "info.circle.fill").foregroundStyle(.blue).font(.caption)
            Text("IRS Rate: $\(String(format: "%.3f", rateManager.rate))/mi  •  Effective \(rateManager.effectiveDate.formatted(.dateTime.month(.abbreviated).day().year()))")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal).padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }

    private var filterBar: some View {
        Picker("Filter by Company", selection: $filterCompany) {
            ForEach(companies, id: \.self) { Text($0).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal).padding(.vertical, 8)
    }
}

// MARK: - Row View

struct MileageRowView: View {
    let record: MileageRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(record.employeeName.isEmpty ? "—" : record.employeeName)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1f mi", record.miles))
                    .font(.headline)
            }
            HStack(spacing: 4) {
                Label(record.company, systemImage: "building.2").font(.subheadline)
                Text("·").foregroundStyle(.secondary)
                Label(record.project, systemImage: "folder.fill").font(.subheadline)
            }
            .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(record.date, style: .date)
                Text(record.startTime, style: .time)
                if let end = record.endTime {
                    Text("→ \(end.formatted(date: .omitted, time: .shortened))")
                }
                Spacer()
                Text(record.reimbursement, format: .currency(code: "USD"))
                    .fontWeight(.semibold).foregroundStyle(.green)
            }
            .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add / Edit Sheet

struct AddMileageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var rateManager: IRSRateManager

    var existing: MileageRecord?

    @State private var date = Date()
    @State private var startTime = Date()
    @State private var hasEndTime = false
    @State private var endTime = Date()
    @State private var employeeName = ""
    @State private var company: MileageCompany = .workerBz
    @State private var project = ""
    @State private var milesText = ""
    @State private var notes = ""

    private var miles: Double { Double(milesText) ?? 0 }
    private var reimbursement: Double { miles * rateManager.rate }

    private var canSave: Bool {
        !employeeName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !project.trimmingCharacters(in: .whitespaces).isEmpty &&
        miles > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    DatePicker("Start Time", selection: $startTime, displayedComponents: .hourAndMinute)
                    Toggle("Include End Time", isOn: $hasEndTime.animation())
                    if hasEndTime {
                        DatePicker("End Time", selection: $endTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Employee & Company") {
                    TextField("Employee Name", text: $employeeName)
                        .textContentType(.name)
                    Picker("Company", selection: $company) {
                        ForEach(MileageCompany.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                }

                Section("Project / Customer") {
                    TextField("Project or customer name", text: $project)
                        .autocorrectionDisabled()
                }

                Section {
                    HStack {
                        Text("Miles Driven")
                        Spacer()
                        TextField("0.0", text: $milesText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("IRS Rate")
                        Spacer()
                        Text("$\(String(format: "%.3f", rateManager.rate))/mi")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Reimbursement")
                            .fontWeight(.medium)
                        Spacer()
                        Text(reimbursement, format: .currency(code: "USD"))
                            .fontWeight(.semibold).foregroundStyle(.green)
                    }
                } header: { Text("Mileage") }

                Section("Notes (Optional)") {
                    TextField("Add any notes…", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(existing == nil ? "New Entry" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
        }
        .onAppear { loadExisting() }
    }

    private func loadExisting() {
        guard let r = existing else { return }
        date = r.date
        startTime = r.startTime
        hasEndTime = r.endTime != nil
        endTime = r.endTime ?? Date()
        employeeName = r.employeeName
        company = MileageCompany(rawValue: r.company) ?? .workerBz
        project = r.project
        milesText = r.miles > 0 ? String(format: "%.1f", r.miles) : ""
        notes = r.notes
    }

    private func save() {
        let name = employeeName.trimmingCharacters(in: .whitespaces)
        let proj = project.trimmingCharacters(in: .whitespaces)
        if let r = existing {
            r.date = date
            r.startTime = startTime
            r.endTime = hasEndTime ? endTime : nil
            r.employeeName = name
            r.company = company.rawValue
            r.project = proj
            r.miles = miles
            r.irsRate = rateManager.rate
            r.notes = notes
        } else {
            modelContext.insert(MileageRecord(
                date: date,
                startTime: startTime,
                endTime: hasEndTime ? endTime : nil,
                employeeName: name,
                company: company.rawValue,
                project: proj,
                miles: miles,
                irsRate: rateManager.rate,
                notes: notes
            ))
        }
        dismiss()
    }
}

// MARK: - IRS Rate Settings

struct IRSRateSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var rateManager: IRSRateManager

    @State private var rateText = ""
    @State private var effectiveDate = Date()
    @State private var showConfirmation = false

    private var newRate: Double? {
        guard let d = Double(rateText), d > 0 else { return nil }
        return d
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Current Rate", value: "$\(String(format: "%.3f", rateManager.rate))/mi")
                    LabeledContent("Effective", value: rateManager.effectiveDate.formatted(.dateTime.month(.wide).day().year()))
                    LabeledContent("Last Updated") {
                        Text(rateManager.lastUpdated, style: .relative)
                    }
                } header: { Text("Active IRS Business Mileage Rate") }

                Section {
                    HStack {
                        Text("$ per mile")
                        Spacer()
                        TextField("e.g. 0.700", text: $rateText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                    }
                    DatePicker("Effective Date", selection: $effectiveDate, displayedComponents: .date)
                    Button("Update Rate") {
                        if let r = newRate {
                            rateManager.update(rate: r, effectiveDate: effectiveDate)
                            showConfirmation = true
                        }
                    }
                    .disabled(newRate == nil)
                } header: {
                    Text("Update Rate")
                } footer: {
                    Text("IRS standard business mileage rates: 2025 = $0.700/mi. Visit irs.gov to check for the latest announced rate and update it here.")
                }

                Section("IRS Resources") {
                    Link("IRS Standard Mileage Rates",
                         destination: URL(string: "https://www.irs.gov/tax-professionals/standard-mileage-rates")!)
                }
            }
            .navigationTitle("IRS Rate Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                rateText = String(format: "%.3f", rateManager.rate)
                effectiveDate = rateManager.effectiveDate
            }
            .alert("Rate Updated", isPresented: $showConfirmation) {
                Button("OK") { dismiss() }
            } message: {
                Text("IRS rate set to $\(String(format: "%.3f", rateManager.rate))/mi, effective \(rateManager.effectiveDate.formatted(.dateTime.month(.wide).day().year())).")
            }
        }
    }
}
