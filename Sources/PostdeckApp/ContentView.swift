import PostdeckCore
import SwiftUI

/// Three columns under a hidden title bar: the slideshows, the slides of the selected one, and the stage.
/// While the slideshow plays, the slide alone takes their place.
struct ContentView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    Group {
      if model.isPresenting {
        SlideshowView()
      } else {
        HStack(spacing: 0) {
          Sidebar()
            .frame(width: Metrics.sidebarWidth)
            .background(Surface.sidebar)
          Rectangle().fill(Surface.hairline).frame(width: 1)
          Navigator()
            .frame(width: Metrics.navigatorWidth)
            .background(Surface.panel)
          Rectangle().fill(Surface.hairline).frame(width: 1)
          Stage()
        }
      }
    }
    .ignoresSafeArea()
    .alert(
      "Postdeck",
      isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    ) {
      Button("OK") {}
    } message: {
      Text(model.errorMessage ?? "")
    }
  }
}

struct Sidebar: View {
  @Environment(AppModel.self) private var model
  @State private var deleting: Deck?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Spacer()
        Button {
          model.createDeck()
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
        }
        .buttonStyle(HoverButtonStyle())
        .help("New Slideshow (⌘N)")
      }
      .padding(.horizontal, 12)
      .frame(height: Metrics.topBar)

      SectionLabel(text: "Slideshows")
        .padding(.horizontal, 20)
        .padding(.bottom, 8)

      ScrollView {
        VStack(spacing: 2) {
          ForEach(model.library.decks) { deck in
            DeckRow(deck: deck) { deleting = deck }
          }
        }
        .padding(.horizontal, 12)
      }

      ServerStatusView()
        .padding(12)
    }
    .confirmationDialog(
      "Delete “\(deleting?.name ?? "")”?",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    ) {
      Button("Delete", role: .destructive) {
        if let deleting {
          model.deleteDeck(deleting.id)
        }
      }
    } message: {
      let count = deleting?.cards.count ?? 0
      Text(count == 1 ? "Its post is deleted too." : "Its \(count) posts are deleted too.")
    }
  }
}

/// A slideshow in the sidebar. Double-click the name to rename it, or drop a slide on it to move the slide there.
struct DeckRow: View {
  @Environment(AppModel.self) private var model
  let deck: Deck
  let onDelete: () -> Void
  @State private var hovering = false
  @State private var isDropTarget = false
  @State private var name = ""
  @FocusState private var editing: Bool

  private var isSelected: Bool { model.currentDeckID == deck.id }
  private var isRenaming: Bool { model.renamingDeckID == deck.id }

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "play.rectangle.fill")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white)
        .frame(width: 24, height: 24)
        .background(
          isSelected ? AnyShapeStyle(.white.opacity(0.2)) : AnyShapeStyle(Brand.gradient),
          in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
      if isRenaming {
        TextField("Name", text: $name)
          .textFieldStyle(.plain)
          .font(Typography.bodyStrong)
          .focused($editing)
          .onSubmit(commit)
          .onExitCommand { model.renamingDeckID = nil }
          .onChange(of: editing) { _, isEditing in
            if !isEditing { commit() }
          }
          .onAppear {
            name = deck.name
            editing = true
          }
      } else {
        Text(deck.name)
          .font(Typography.bodyStrong)
          .lineLimit(1)
      }
      Spacer(minLength: 4)
      Text("\(deck.cards.count)")
        .font(Typography.captionStrong)
        .monospacedDigit()
        .contentTransition(.numericText(value: Double(deck.cards.count)))
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(isSelected ? Color.white.opacity(0.2) : Surface.hover, in: Capsule())
    }
    .foregroundStyle(isSelected ? .white : .primary)
    .padding(.horizontal, 8)
    .frame(height: 38)
    .background {
      RoundedRectangle(cornerRadius: 9, style: .continuous)
        .fill(isSelected ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(hovering ? Surface.hover : .clear))
    }
    .overlay {
      if isDropTarget {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
          .fill(Brand.blue.opacity(0.12))
          .strokeBorder(Brand.blue, lineWidth: 2)
      }
    }
    .animation(.snappy(duration: 0.2), value: deck.cards.count)
    .animation(.easeOut(duration: 0.12), value: isDropTarget)
    .contentShape(Rectangle())
    .onHover { hovering = $0 }
    .dropDestination(for: String.self) { ids, _ in
      guard !isSelected, let id = ids.first, model.cards.contains(where: { $0.id == id }) else { return false }
      model.moveCard(id, to: deck.id)
      return true
    } isTargeted: { isDropTarget = $0 && !isSelected }
    .onTapGesture { model.currentDeckID = deck.id }
    .simultaneousGesture(TapGesture(count: 2).onEnded { model.renamingDeckID = deck.id })
    .contextMenu {
      Button("Rename") { model.renamingDeckID = deck.id }
      Divider()
      Button("Delete…", role: .destructive, action: onDelete)
    }
  }

  private func commit() {
    guard isRenaming else { return }
    model.renameDeck(deck.id, to: name)
    model.renamingDeckID = nil
  }
}

struct ServerStatusView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    HStack(spacing: 10) {
      Circle()
        .fill(color)
        .frame(width: 8, height: 8)
        .background(Circle().fill(color.opacity(0.25)).frame(width: 16, height: 16))
      VStack(alignment: .leading, spacing: 1) {
        Text(title)
          .font(Typography.bodyStrong)
        Text(subtitle)
          .font(Typography.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(10)
    .background(Surface.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Surface.hairline))
  }

  private var title: String {
    switch model.serverState {
    case .listening: "Ready"
    case .failed: "Can't receive posts"
    case nil: "Starting…"
    }
  }

  private var subtitle: String {
    switch model.serverState {
    case .listening: "Send posts from X with the extension"
    case .failed(let message): "\(message) Trying again…"
    case nil: "Opening port \(Postdeck.port)"
    }
  }

  private var color: Color {
    switch model.serverState {
    case .listening: .green
    case .failed: .orange
    case nil: .secondary
    }
  }
}
