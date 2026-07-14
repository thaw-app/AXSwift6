import ApplicationServices
import AXSwift6
import Testing

@Suite("Constants")
struct ConstantsTests {
    @Test("Roles round-trip through raw values", arguments: [
        Role.unknown, .button, .radioButton, .checkBox, .slider, .tabGroup, .textField,
        .staticText, .textArea, .scrollArea, .popUpButton, .menuButton, .table, .application,
        .group, .radioGroup, .list, .scrollBar, .valueIndicator, .image, .menuBar, .menu,
        .menuItem, .menuBarItem, .column, .row, .toolbar, .busyIndicator, .progressIndicator,
        .window, .drawer, .systemWide, .outline, .incrementor, .browser, .comboBox, .splitGroup,
        .splitter, .colorWell, .growArea, .sheet, .helpTag, .matte, .ruler, .rulerMarker, .link,
        .disclosureTriangle, .grid, .relevanceIndicator, .levelIndicator, .cell, .popover,
        .layoutArea, .layoutItem, .handle,
    ])
    func rolesRoundTrip(role: Role) {
        #expect(Role(rawValue: role.rawValue) == role)
        #expect(role.rawValue.hasPrefix("AX"))
    }

    @Test("Subroles round-trip through raw values", arguments: [
        Subrole.unknown, .closeButton, .zoomButton, .minimizeButton, .toolbarButton, .tableRow,
        .outlineRow, .secureTextField, .standardWindow, .dialog, .systemDialog, .floatingWindow,
        .systemFloatingWindow, .incrementArrow, .decrementArrow, .incrementPage, .decrementPage,
        .searchField, .textAttachment, .textLink, .timeline, .sortButton, .ratingIndicator,
        .contentList, .definitionList, .fullScreenButton, .toggle, .switchSubrole, .descriptionList,
    ])
    func subrolesRoundTrip(subrole: Subrole) {
        #expect(Subrole(rawValue: subrole.rawValue) == subrole)
    }

    @Test("Actions round-trip through raw values", arguments: [
        Action.press, .increment, .decrement, .confirm, .pick, .cancel, .raise, .showMenu,
        .delete, .showAlternateUI, .showDefaultUI,
    ])
    func actionsRoundTrip(action: Action) {
        #expect(Action(rawValue: action.rawValue) == action)
    }

    @Test("Notifications round-trip through raw values", arguments: [
        AXNotification.mainWindowChanged, .focusedWindowChanged, .focusedUIElementChanged,
        .focusedTabChanged, .applicationActivated, .applicationDeactivated, .applicationHidden,
        .applicationShown, .windowCreated, .windowMoved, .windowResized, .windowMiniaturized,
        .windowDeminiaturized, .drawerCreated, .sheetCreated, .uiElementDestroyed, .valueChanged,
        .titleChanged, .resized, .moved, .created, .layoutChanged, .helpTagCreated,
        .selectedTextChanged, .rowCountChanged, .selectedChildrenChanged, .selectedRowsChanged,
        .selectedColumnsChanged, .loadComplete, .rowExpanded, .rowCollapsed, .selectedCellsChanged,
        .unitsChanged, .selectedChildrenMoved, .announcementRequested,
    ])
    func notificationsRoundTrip(notification: AXNotification) {
        #expect(AXNotification(rawValue: notification.rawValue) == notification)
    }

    @Test("Orientations use documented raw values")
    func orientationsUseDocumentedRawValues() {
        #expect(Orientation.unknown.rawValue == 0)
        #expect(Orientation.vertical.rawValue == 1)
        #expect(Orientation.horizontal.rawValue == 2)
        #expect(Orientation(rawValue: 1) == .vertical)
    }

    @Test("Common attributes match Apple constant names", arguments: [
        (Attribute.role, "AXRole"),
        (Attribute.title, "AXTitle"),
        (Attribute.windows, "AXWindows"),
        (Attribute.focusedUIElement, "AXFocusedUIElement"),
        (Attribute.extrasMenuBar, "AXExtrasMenuBar"),
        (Attribute.position, "AXPosition"),
        (Attribute.size, "AXSize"),
    ] as [(Attribute, String)])
    func commonAttributesMatchAppleNames(attribute: Attribute, rawValue: String) {
        #expect(attribute.rawValue == rawValue)
        #expect(Attribute(rawValue: rawValue) == attribute)
    }
}
