import SwiftUI

struct DashboardRootView: View {
    @EnvironmentObject private var telemetry: TelemetryStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var settingsVisible = false
    @State private var page: DashboardPage = .main

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                (colorScheme == .dark ? Color.black : Color(red: 0.94, green: 0.95, blue: 0.96))
                    .ignoresSafeArea()
                Group {
                    if page == .main {
                        switch telemetry.style {
                        case .minimal: MinimalDashboardView()
                        case .sportOne: SportOneDashboardView()
                        case .sportTwo: SportTwoDashboardView()
                        }
                    } else {
                        SensorPageView(page: page)
                    }
                }
                .environmentObject(telemetry)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 35)
                        .onEnded(changeDashboard)
                )
                .zIndex(0)

                VStack {
                    HStack(spacing: 14) {
                        if page != .main {
                            Text(page.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary.opacity(0.9))
                        }
                        ConnectionBadge(label: "OBD", connected: telemetry.obdConnected)
                        ConnectionBadge(label: "VHAL", connected: telemetry.vhalConnected)
                        Button { settingsVisible.toggle() } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 19, weight: .medium))
                                .frame(width: 46, height: 46)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.primary.opacity(0.72))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, max(geometry.safeAreaInsets.top, 12))
                    .padding(.leading, geometry.safeAreaInsets.leading + 14)
                    .padding(.trailing, geometry.safeAreaInsets.trailing + 14)
                    Spacer()
                    HStack(spacing: 7) {
                        ForEach(DashboardPage.allCases) { item in
                            Capsule()
                                .fill(item == page ? Color.primary.opacity(0.9) : Color.primary.opacity(0.25))
                                .frame(width: item == page ? 18 : 7, height: 5)
                        }
                    }
                    .padding(.bottom, 5)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .zIndex(100)

                if settingsVisible {
                    SettingsOverlay(isPresented: $settingsVisible)
                        .environmentObject(telemetry)
                        .zIndex(200)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
        .preferredColorScheme(preferredColorScheme)
    }

    private var preferredColorScheme: ColorScheme? {
        switch telemetry.appearance {
        case .system: nil
        case .day: .light
        case .night: .dark
        }
    }

    private func changeDashboard(_ value: DragGesture.Value) {
        let horizontal = value.translation.width
        guard abs(horizontal) > abs(value.translation.height), abs(horizontal) >= 55 else { return }
        let pages = DashboardPage.allCases
        guard let current = pages.firstIndex(of: page) else { return }
        let next = horizontal < 0
            ? min(current + 1, pages.count - 1)
            : max(current - 1, 0)
        guard next != current else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            page = pages[next]
        }
    }
}

private struct ConnectionBadge: View {
    let label: String
    let connected: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(connected ? Color.green : Color.gray.opacity(0.55)).frame(width: 7, height: 7)
            Text(label).font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(.primary.opacity(0.72))
    }
}

private struct SettingsOverlay: View {
    @EnvironmentObject private var telemetry: TelemetryStore
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea().onTapGesture { isPresented = false }
            VStack(spacing: 18) {
                HStack {
                    Text("GÖRÜNÜM").font(.headline)
                    Spacer()
                    Button { isPresented = false } label: { Image(systemName: "xmark.circle.fill") }
                }
                Picker("Görünüm", selection: $telemetry.style) {
                    ForEach(DashboardStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Renk modu", selection: $telemetry.appearance) {
                    ForEach(DashboardAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Divider().overlay(Color.primary.opacity(0.15))
                VStack(alignment: .leading, spacing: 8) {
                    Text(telemetry.obdStatus)
                    Text(telemetry.vhalStatus)
                }
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.primary.opacity(0.72))
                .frame(maxWidth: .infinity, alignment: .leading)
                Divider().overlay(Color.primary.opacity(0.15))
                Text("SENSÖRLER").font(.caption).foregroundStyle(.primary.opacity(0.6))
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(SensorKey.allCases.filter(\.isUserSelectable), id: \.self) { key in
                            Toggle(key.title, isOn: Binding(
                                get: { telemetry.visibleSensors.contains(key) },
                                set: { telemetry.setVisible(key, $0) }
                            ))
                            .font(.system(size: 13, design: .rounded))
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
            .padding(24)
            .frame(maxWidth: 440)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding()
        }
    }
}
