import SwiftUI

struct DashboardRootView: View {
    @EnvironmentObject private var telemetry: TelemetryStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var settingsVisible = false
    @State private var exitConfirmationVisible = false
    @State private var standby = false
    @State private var page: DashboardPage = .main

    var body: some View {
        GeometryReader { geometry in
            let contentTop = max(geometry.safeAreaInsets.top, 8) + 52
            let horizontalInset = max(geometry.safeAreaInsets.leading, geometry.safeAreaInsets.trailing)
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
                .padding(.top, contentTop)
                .padding(.bottom, 18)
                .padding(.horizontal, horizontalInset)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 35)
                        .onEnded(changeDashboard)
                )
                .zIndex(0)
                .opacity(standby ? 0 : 1)
                .allowsHitTesting(!standby)

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
                .opacity(standby ? 0 : 1)
                .allowsHitTesting(!standby)

                VStack {
                    HStack {
                        Spacer()
                        Button { exitConfirmationVisible = true } label: {
                            Image(systemName: "power")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 46, height: 46)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color.red.opacity(0.82))
                    }
                    Spacer()
                }
                .padding(.top, max(geometry.safeAreaInsets.top, 12))
                .padding(.trailing, geometry.safeAreaInsets.trailing + 14)
                .zIndex(110)
                .opacity(standby ? 0 : 1)
                .allowsHitTesting(!standby)

                if settingsVisible {
                    SettingsOverlay(isPresented: $settingsVisible)
                        .environmentObject(telemetry)
                        .zIndex(200)
                }

                if standby {
                    StandbyOverlay {
                        UIApplication.shared.isIdleTimerDisabled = true
                        telemetry.start()
                        standby = false
                    }
                    .zIndex(300)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
        .preferredColorScheme(preferredColorScheme)
        .onAppear { telemetry.setActivePage(page) }
        .onChange(of: page) { _, selected in telemetry.setActivePage(selected) }
        .alert("Bağlantılar kapatılsın mı?", isPresented: $exitConfirmationVisible) {
            Button("Vazgeç", role: .cancel) {}
            Button("Çıkış", role: .destructive) { enterStandby() }
        } message: {
            Text("OBD ve VHAL bağlantıları kesilecek, ekranın açık kalma kilidi kaldırılacak.")
        }
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

    private func enterStandby() {
        settingsVisible = false
        telemetry.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        standby = true
    }
}

private struct StandbyOverlay: View {
    let restart: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "power")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Color.red.opacity(0.8))
                Text("Bağlantılar kapatıldı")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Button("YENİDEN BAŞLAT", action: restart)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.72, green: 0.16, blue: 0.13))
            }
            .foregroundStyle(.white)
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
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.72).ignoresSafeArea().onTapGesture { isPresented = false }
                VStack(spacing: 10) {
                    HStack {
                        Text("GÖRÜNÜM").font(.headline)
                        Spacer()
                        Button { isPresented = false } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .frame(width: 44, height: 36)
                        }
                        .buttonStyle(.plain)
                    }
                    Picker("Görünüm", selection: $telemetry.style) {
                        ForEach(DashboardStyle.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Renk modu", selection: $telemetry.appearance) {
                        ForEach(DashboardAppearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(telemetry.obdStatus)
                            Text(telemetry.vhalStatus)
                        }
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Divider().overlay(Color.primary.opacity(0.15))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("SENSÖRLER").font(.caption).foregroundStyle(.primary.opacity(0.6))
                            ScrollView {
                                LazyVStack(spacing: 5) {
                                    ForEach(SensorKey.allCases.filter(\.isUserSelectable), id: \.self) { key in
                                        Toggle(key.title, isOn: Binding(
                                            get: { telemetry.visibleSensors.contains(key) },
                                            set: { telemetry.setVisible(key, $0) }
                                        ))
                                        .font(.system(size: 12, design: .rounded))
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
                .frame(width: min(620, geometry.size.width - 48),
                       height: min(350, geometry.size.height - 24))
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}
