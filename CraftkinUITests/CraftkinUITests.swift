import XCTest

final class CraftkinUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreateFamilySpaceJourney() throws {
        let app = makeCleanApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["Keep family know-how alive."].waitForExistence(timeout: 5))
        app.buttons["Get Started"].tap()
        XCTAssertTrue(app.staticTexts["From memory to lesson."].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Your family stories stay private."].waitForExistence(timeout: 5))
        app.buttons["Set Up My Space"].tap()
        XCTAssertTrue(app.staticTexts["Who will you learn with?"].waitForExistence(timeout: 5))
        app.buttons["Create a Family Space"].tap()

        let nameField = app.textFields["Family Space name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.tap()
        nameField.typeText("The Carter Family")

        let createButton = app.buttons["Create Family Space"]
        XCTAssertTrue(createButton.isEnabled)
        createButton.tap()

        XCTAssertTrue(app.staticTexts["Your Family Space is ready."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["The Carter Family"].exists)
        app.buttons["Continue to Library"].tap()
        XCTAssertTrue(app.staticTexts["Keep their know-how alive."].waitForExistence(timeout: 3))
    }

    @MainActor
    func testPopulatedLibraryDiscoveryJourney() throws {
        let app = makeLibraryApp(state: "populated")
        app.launch()

        XCTAssertTrue(app.staticTexts["Keep their know-how alive."].waitForExistence(timeout: 5))
        app.buttons["See All"].tap()
        XCTAssertTrue(app.staticTexts["All Skills"].waitForExistence(timeout: 3))

        app.buttons["Search Library"].tap()
        let searchField = app.textFields["Search skills, people, or tools"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("wood")
        XCTAssertTrue(app.staticTexts["2 results"].waitForExistence(timeout: 3))

        app.buttons["Clear search text"].tap()
        searchField.tap()
        searchField.typeText("violin")
        XCTAssertTrue(app.staticTexts["No family skills found."].waitForExistence(timeout: 3))
        app.buttons["Clear Search"].tap()
        XCTAssertTrue(app.staticTexts["All Skills"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSkillAndMakerDetailJourney() throws {
        let app = makeLibraryApp(state: "populated")
        app.launch()

        app.buttons["Grandma’s Apple Pie"].tap()
        XCTAssertTrue(app.staticTexts["Grandma’s Apple Pie"].waitForExistence(timeout: 3))
        for _ in 0..<4 where !app.staticTexts["Lesson Steps"].exists {
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Lesson Steps"].exists)
        for _ in 0..<4 where !app.buttons["Grandma profile"].exists {
            app.swipeDown()
        }
        app.buttons["Grandma profile"].tap()
        XCTAssertTrue(app.staticTexts["Margaret Carter"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Her Story"].exists)
    }

    @MainActor
    func testLessonBackReturnsToItsRealOrigin() throws {
        let app = makeLibraryApp(state: "populated")
        app.launch()

        app.buttons["Grandma’s Apple Pie"].tap()
        XCTAssertTrue(app.staticTexts["Grandma’s Apple Pie"].waitForExistence(timeout: 3))
        app.buttons["Back to Library"].tap()
        XCTAssertTrue(app.staticTexts["Keep their know-how alive."].waitForExistence(timeout: 3))

        app.buttons["See All"].tap()
        app.buttons["Grandma’s Apple Pie"].tap()
        XCTAssertTrue(app.staticTexts["Grandma’s Apple Pie"].waitForExistence(timeout: 3))
        app.buttons["Back to All Skills"].tap()
        XCTAssertTrue(app.staticTexts["All Skills"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testProfileShortcutsUseSavedNameOnHomeAndFamily() throws {
        let app = makeProfileApp(route: "profile")
        app.launch()
        app.buttons["Edit Profile"].tap()
        let field = app.textFields["Profile name"]
        let current = field.value as? String ?? ""
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count) + "Taylor Brooks")
        app.buttons["Save"].tap()
        for tab in ["Library", "Family"] {
            app.buttons[tab].tap()
            if tab == "Library" {
                let heading = app.staticTexts["Keep their know-how alive."]
                XCTAssertGreaterThanOrEqual(heading.frame.minX, app.windows.firstMatch.frame.minX + 16)
                XCTAssertLessThanOrEqual(heading.frame.maxX, app.windows.firstMatch.frame.maxX - 16)
            }
            let shortcut = app.buttons["Open Profile"]
            XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
            XCTAssertTrue((shortcut.value as? String ?? "").contains("Taylor Brooks"))
            shortcut.tap()
            XCTAssertTrue(app.staticTexts["My Profile"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Taylor Brooks"].exists)
        }
    }

    @MainActor
    func testProfileAvatarPickerSaveAndRestoreDefault() throws {
        let app = makeProfileApp(route: "profile")
        app.launch()
        app.buttons["Edit Profile Photo"].tap()
        app.buttons["Choose Profile Photo"].tap()
        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 30), app.debugDescription)
        photo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        if app.buttons["Add"].waitForExistence(timeout: 1) { app.buttons["Add"].tap() }
        XCTAssertTrue(app.buttons["Use Default Photo"].waitForExistence(timeout: 15))
        keepScreenshot(named: "Profile-Selected-Photo")
        app.buttons["Save"].tap()
        XCTAssertEqual(app.buttons["Edit Profile Photo"].value as? String, "Custom photo")
        keepScreenshot(named: "Profile-Saved-Avatar")
        for tab in ["Library", "Family"] {
            app.buttons[tab].tap()
            let shortcut = app.buttons["Open Profile"]
            XCTAssertTrue(shortcut.waitForExistence(timeout: 5))
            XCTAssertTrue((shortcut.value as? String ?? "").contains("Custom photo"))
            keepScreenshot(named: "Profile-Synced-\(tab)")
            shortcut.tap()
            XCTAssertTrue(app.staticTexts["My Profile"].waitForExistence(timeout: 5))
        }
        app.terminate()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-openProfile", "-familyRoute", "profile"]
        app.launch()
        XCTAssertEqual(app.buttons["Edit Profile Photo"].value as? String, "Custom photo")
        app.buttons["Edit Profile Photo"].tap()
        app.buttons["Use Default Photo"].tap()
        app.buttons["Cancel"].tap()
        XCTAssertEqual(app.buttons["Edit Profile Photo"].value as? String, "Custom photo")
        app.buttons["Edit Profile Photo"].tap()
        app.buttons["Use Default Photo"].tap()
        app.buttons["Save"].tap()
        XCTAssertEqual(app.buttons["Edit Profile Photo"].value as? String, "Default photo")
    }

    @MainActor
    func testProfileEditorSaveCancelAndSettingsEntry() throws {
        let app = makeProfileApp(route: "profile")
        app.launch()
        app.buttons["Edit Profile Photo"].tap()
        XCTAssertTrue(app.buttons["Choose Profile Photo"].waitForExistence(timeout: 5))
        let name = app.textFields["Profile name"]
        XCTAssertTrue(name.exists)
        let original = name.value as? String ?? ""
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: original.count) + "Not Saved")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts[original].exists)
        app.buttons["Edit Profile"].tap()
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: original.count) + "Alex Morgan")
        keepScreenshot(named: "Profile-Editor")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Alex Morgan"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-openProfile", "-familyRoute", "profile"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Alex Morgan"].waitForExistence(timeout: 5))
        app.buttons["Settings"].firstMatch.tap()
        app.buttons["Edit Profile"].tap()
        XCTAssertTrue(app.buttons["Choose Profile Photo"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["Profile name"].value as? String, "Alex Morgan")
        app.buttons["Cancel"].tap()
    }

    @MainActor
    func testNormalLibraryLaunchIncludesBundledSkills() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Keep their know-how alive."].waitForExistence(timeout: 5))
        tap(app.buttons["See All"], until: app.staticTexts["All Skills"])
        XCTAssertTrue(app.buttons["Grandma’s Apple Pie"].exists)
        app.swipeUp()
        XCTAssertTrue(app.buttons["Dad’s Bike Repair"].exists)
        XCTAssertTrue(app.buttons["Grandpa’s Woodwork"].exists)
        keepScreenshot(named: "Normal-Launch-Bundled-Skills")
        app.terminate()
        app.launch()
        tap(app.buttons["See All"], until: app.staticTexts["All Skills"])
        XCTAssertTrue(app.buttons["Grandma’s Apple Pie"].exists)
    }

    @MainActor
    func testLocalStorageHidesDeferredCloudFeatures() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-openProfile", "-familyRoute", "storage", "-libraryFixture", "populated"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Storage"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Stored on this iPhone"].exists)
        XCTAssertFalse(app.switches["iCloud Sync"].exists)
        XCTAssertFalse(app.switches["Optimize Device Storage"].exists)
        XCTAssertFalse(app.staticTexts["Automatic optimization requires a verified cloud backup."].exists)
        XCTAssertTrue(app.switches["Download over Wi-Fi only"].exists)
        XCTAssertTrue(app.buttons["Remove All Downloads"].exists)
        keepScreenshot(named: "Local-Storage-No-Cloud-Controls")
        app.buttons["Back to Settings"].tap()
        XCTAssertTrue(app.buttons["Storage"].exists || app.staticTexts["Storage"].exists)
        XCTAssertFalse(app.staticTexts["Storage & iCloud"].exists)
    }

    @MainActor
    func testVariedFamilyActivityAndLessonDestination() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-openFamily", "-familyRoute", "activity", "-libraryFixture", "populated"]
        app.launch()
        let garden = app.staticTexts["shared a practice for Grandpa’s Garden Cuttings."]
        let wreath = app.staticTexts["published Holiday Wreath Making."]
        XCTAssertTrue(garden.waitForExistence(timeout: 5))
        XCTAssertTrue(wreath.exists)
        XCTAssertTrue(app.staticTexts["completed Dad’s Bike Repair."].exists)
        keepScreenshot(named: "Family-Activity-Varied")
        app.buttons["Practice"].tap()
        XCTAssertTrue(garden.exists)
        XCTAssertFalse(wreath.exists)
        app.buttons["New Lessons"].tap()
        XCTAssertTrue(wreath.exists)
        XCTAssertFalse(garden.exists)
        scrollAndTap(wreath, in: app)
        // Existing learners resume in the player; fresh lessons open materials.
        if app.buttons["Back to Materials"].waitForExistence(timeout: 2) {
            app.buttons["Back to Materials"].tap()
        }
        XCTAssertTrue(app.buttons["Back to Learn"].waitForExistence(timeout: 5))
        app.buttons["Back to Learn"].tap()
        XCTAssertTrue(app.images["Cover for Holiday Wreath Making"].waitForExistence(timeout: 5))
        keepScreenshot(named: "Family-Activity-Wreath-Destination")
    }

    @MainActor
    func testMakerArchiveSkillPhotosAndTitles() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-openFamily", "-familyRoute", "maker", "-libraryFixture", "populated"]
        app.launch()
        let cards = ["FamilyBaking", "SkillPasta", "SkillWreath"].map {
            app.otherElements["maker-skill-\($0)"]
        }
        for _ in 0..<5 where !app.staticTexts["Her Skills"].isHittable { app.swipeUp() }
        app.swipeUp()
        for card in cards { XCTAssertTrue(card.waitForExistence(timeout: 3)) }
        keepScreenshot(named: "Maker-Archive-Uniform-Pasta")
        // Photo accessibility bounds include uncropped source pixels; verify
        // card edges and equal sizes using the retained simulator screenshot.
        XCTAssertEqual(cards[0].label, "Grandma’s Apple Pie")
        XCTAssertEqual(cards[1].label, "Sunday Pasta")
        XCTAssertEqual(cards[2].label, "Holiday Wreath")
    }

    @MainActor
    func testSkillCardsHaveUniformSizeOnHomeAndAllSkills() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-libraryFixture", "populated"]
        app.launch()

        func checkCards(_ screen: String) {
            let bike = app.buttons["Dad’s Bike Repair"]
            let wood = app.buttons["Grandpa’s Woodwork"]
            for _ in 0..<6 where !bike.isHittable || !wood.isHittable { app.swipeUp() }
            XCTAssertTrue(bike.isHittable)
            XCTAssertTrue(wood.isHittable)
            XCTAssertEqual(bike.frame.width, wood.frame.width, accuracy: 1, screen)
            XCTAssertEqual(bike.frame.height, wood.frame.height, accuracy: 1, screen)
            if bike.frame.minX < wood.frame.minX {
                XCTAssertEqual(bike.frame.minY, wood.frame.minY, accuracy: 1, screen)
            }
            keepScreenshot(named: "Uniform-Cards-\(screen)")
        }
        checkCards("Home")
        for _ in 0..<6 where !app.buttons["See All"].isHittable { app.swipeDown() }
        app.buttons["See All"].tap()
        XCTAssertTrue(app.staticTexts["All Skills"].waitForExistence(timeout: 5))
        checkCards("All-Skills")
    }

    @MainActor
    func testBakingWreathAndGrandpaUpdates() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-libraryFixture", "populated"]
        app.launch()
        tap(app.buttons["See All"], until: app.staticTexts["All Skills"])
        keepScreenshot(named: "Photo3-All-Skills")
        func searchAndOpen(_ title: String, query: String) {
            app.buttons["Search Library"].tap()
            let field = app.textFields["Search skills, people, or tools"]
            field.tap()
            field.typeText(query)
            XCTAssertTrue(app.buttons[title].waitForExistence(timeout: 3))
            app.buttons[title].tap()
        }
        func returnToAllSkills() {
            app.buttons["Back to Search"].tap()
            app.buttons["Cancel"].tap()
            XCTAssertTrue(app.staticTexts["All Skills"].waitForExistence(timeout: 3))
        }
        searchAndOpen("Grandpa’s Garden Cuttings", query: "cuttings")
        XCTAssertTrue(app.buttons["Grandpa profile"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Robert Carter"].exists)
        keepScreenshot(named: "Photo3-Grandpa-Garden")
        returnToAllSkills()
        searchAndOpen("Holiday Wreath Making", query: "wreath")
        XCTAssertTrue(app.images["Holiday Wreath Making cover"].waitForExistence(timeout: 3))
        keepScreenshot(named: "Photo3-Wreath")
        returnToAllSkills()
        searchAndOpen("Grandma’s Apple Pie", query: "apple")
        XCTAssertTrue(app.images["Grandma’s Apple Pie cover"].waitForExistence(timeout: 3))
        keepScreenshot(named: "Photo3-Baking-Cover")
        scrollAndTap(app.buttons["Continue Learning"], in: app)
        // Preserve existing progress: returning learners resume in the player,
        // while a fresh lesson opens the materials screen.
        if app.buttons["Back to Materials"].waitForExistence(timeout: 2) {
            app.buttons["Back to Materials"].tap()
        }
        XCTAssertTrue(app.buttons["Back to Learn"].waitForExistence(timeout: 3))
        app.buttons["Back to Learn"].tap()
        XCTAssertTrue(app.images["Cover for Grandma’s Apple Pie"].waitForExistence(timeout: 3))
        keepScreenshot(named: "Photo3-Learn-Baking")
    }

    @MainActor
    func testCoverPhotoSelectionStaysInPlace() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-openCapture", "-libraryFixture", "populated"]
        app.launch()
        scrollAndTap(app.buttons["Continue Draft"], in: app)
        XCTAssertTrue(app.staticTexts["Ready for your family."].waitForExistence(timeout: 5))
        let photo = app.buttons["Cover photo 2"]
        photo.tap()
        XCTAssertEqual(photo.value as? String, "Selected")
        keepScreenshot(named: "Photo2-Cover-Stable-Selection")
    }

    @MainActor
    func testAdditionalPhotoAuditScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-openCapture", "-libraryFixture", "populated"]
        app.launch()
        XCTAssertTrue(app.images["A family member teaching a child pottery"].waitForExistence(timeout: 5))
        keepScreenshot(named: "Photo2-Capture-Entry")
        app.buttons["Library"].tap()
        tap(app.buttons["See All"], until: app.staticTexts["All Skills"])
        scrollAndTap(app.buttons["Build a Cedar Birdhouse"], in: app)
        XCTAssertTrue(app.images["Build a Cedar Birdhouse cover"].waitForExistence(timeout: 3))
        keepScreenshot(named: "Photo2-Birdhouse")
        app.buttons["Back to All Skills"].tap()
        app.buttons["Search Library"].tap()
        let search = app.textFields["Search skills, people, or tools"]
        search.tap()
        search.typeText("violin")
        XCTAssertTrue(app.staticTexts["No family skills found."].waitForExistence(timeout: 3))
        if app.keyboards.buttons["return"].exists { app.keyboards.buttons["return"].tap() }
        keepScreenshot(named: "Photo2-Search-Inspiration")
        app.terminate()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-openProfile", "-familyRoute", "help", "-libraryFixture", "populated"]
        app.launch()
        XCTAssertTrue(app.images["A family member teaching a child to fish"].waitForExistence(timeout: 5))
        keepScreenshot(named: "Photo2-Help")
    }

    @MainActor
    func testSuppliedOnboardingPhotos() throws {
        let app = XCUIApplication()
        // NSArgumentDomain overrides the read for this launch only; stored setup is untouched.
        app.launchArguments = ["-uiTesting", "-echoskill.onboarding.completion", "photo-preview"]
        app.launch()
        XCTAssertTrue(app.images["Family members preparing a meal together"].waitForExistence(timeout: 5))
        // Image accessibility frames may report uncropped source bounds; check the
        // surrounding content that previously widened with the source photograph.
        let welcomeAction = app.buttons["Get Started"].frame
        XCTAssertGreaterThanOrEqual(welcomeAction.minX, app.frame.minX + 16)
        XCTAssertLessThanOrEqual(welcomeAction.maxX, app.frame.maxX - 16)
        keepScreenshot(named: "Photos-06-Welcome")
        app.buttons["Get Started"].tap()
        XCTAssertTrue(app.staticTexts["From memory to lesson."].waitForExistence(timeout: 3))
        keepScreenshot(named: "Photos-07-How-It-Works")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.images["An older family member teaching a child to sew"].waitForExistence(timeout: 3))
        keepScreenshot(named: "Photos-08-Privacy")
    }

    @MainActor
    func testSuppliedSkillPhotoNavigation() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        // Do not reset existing lessons, progress, or family data for an asset-only review.
        app.launchArguments = ["-uiTesting", "-openLibrary", "-libraryFixture", "populated"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Keep their know-how alive."].waitForExistence(timeout: 5))
        tap(app.buttons["See All"], until: app.staticTexts["All Skills"])
        keepScreenshot(named: "Photos-01-All-Skills")

        for (index, title) in ["Dad’s Bike Repair", "Grandpa’s Woodwork", "Grandpa’s Garden Cuttings", "Build a Cedar Birdhouse"].enumerated() {
            scrollAndTap(app.buttons[title], in: app)
            XCTAssertTrue(app.images["\(title) cover"].waitForExistence(timeout: 3))
            let heading = app.staticTexts[title].frame
            XCTAssertGreaterThanOrEqual(heading.minX, app.frame.minX + 16)
            XCTAssertLessThanOrEqual(heading.maxX, app.frame.maxX - 16)
            keepScreenshot(named: "Photos-0\(index + 2)-Skill-Detail")
            app.buttons["Back to All Skills"].tap()
            XCTAssertTrue(app.staticTexts["All Skills"].waitForExistence(timeout: 3))
        }

        app.buttons["Family"].tap()
        XCTAssertTrue(app.images["Family members passing on cooking skills together"].waitForExistence(timeout: 3))
        keepScreenshot(named: "Photos-05-Family")
    }

    @MainActor
    func testCaptureApprovedLibraryScreens() throws {
        let app = makeLibraryApp(state: "populated")
        app.launch()

        XCTAssertTrue(app.staticTexts["Keep their know-how alive."].waitForExistence(timeout: 5))
        keepScreenshot(named: "01-Library-Home-Populated")

        app.buttons["See All"].tap()
        XCTAssertTrue(app.staticTexts["All Skills"].waitForExistence(timeout: 3))
        keepScreenshot(named: "03-All-Skills")

        app.buttons["Search Library"].tap()
        let searchField = app.textFields["Search skills, people, or tools"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("wood")
        XCTAssertTrue(app.staticTexts["2 results"].waitForExistence(timeout: 3))
        if app.keyboards.buttons["return"].exists { app.keyboards.buttons["return"].tap() }
        keepScreenshot(named: "04-Search-Results")

        app.buttons["Filter Library"].tap()
        XCTAssertTrue(app.staticTexts["Filter Library"].waitForExistence(timeout: 3))
        keepScreenshot(named: "05-Filter-Sheet")
        app.swipeDown()

        app.buttons["Cancel"].tap()
        app.buttons["Grandma’s Apple Pie"].tap()
        XCTAssertTrue(app.staticTexts["Grandma’s Apple Pie"].waitForExistence(timeout: 3))
        keepScreenshot(named: "06-Skill-Detail")
        app.buttons["Grandma profile"].tap()
        XCTAssertTrue(app.staticTexts["Margaret Carter"].waitForExistence(timeout: 3))
        keepScreenshot(named: "07-Maker-Profile")

        app.buttons["Library"].tap()
        app.buttons["See All"].tap()
        app.buttons["Search Library"].tap()
        let secondSearchField = app.textFields["Search skills, people, or tools"]
        secondSearchField.tap()
        secondSearchField.typeText("violin")
        XCTAssertTrue(app.staticTexts["No family skills found."].waitForExistence(timeout: 3))
        if app.keyboards.buttons["return"].exists { app.keyboards.buttons["return"].tap() }
        keepScreenshot(named: "08-Search-No-Results")

        app.terminate()
        let emptyApp = makeLibraryApp(state: "empty")
        emptyApp.launch()
        XCTAssertTrue(emptyApp.staticTexts["Every skill starts with a story."].waitForExistence(timeout: 5))
        keepScreenshot(named: "02-Library-Home-Empty")
    }

    @MainActor
    func testCaptureLessonCreationJourney() throws {
        let app = makeCaptureApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["Preserve a family skill."].waitForExistence(timeout: 5))
        keepScreenshot(named: "C01-Capture-Entry")
        app.buttons["Record Now"].tap()

        XCTAssertTrue(app.buttons["Stop Recording"].waitForExistence(timeout: 3))
        keepScreenshot(named: "C02-Video-Recording")
        app.buttons["Start Recording"].tap()
        app.buttons["Stop Recording"].tap()

        XCTAssertTrue(app.staticTexts["Tell us what this skill means."].waitForExistence(timeout: 3))
        let titleField = app.textFields["Skill title"]
        titleField.tap()
        titleField.typeText("Grandma's Dumplings")
        let makerField = app.textFields["Maker"]
        makerField.tap()
        makerField.typeText("Grandma Mei")
        let languageField = app.textFields["Spoken language"]
        languageField.tap()
        XCTAssertEqual(languageField.placeholderValue, "English, Spanish…")
        languageField.typeText("English")
        app.swipeDown()
        keepScreenshot(named: "C03-Lesson-Details")
        scrollAndTap(app.buttons["Create Lesson Draft"], in: app)

        XCTAssertTrue(app.staticTexts["Turning a recording into a lesson."].waitForExistence(timeout: 3))
        keepScreenshot(named: "C04-Draft-Processing")
        scrollAndTap(app.buttons["Show Recovery Options"], in: app)
        XCTAssertTrue(app.staticTexts["We couldn't finish one part."].waitForExistence(timeout: 3))
        keepScreenshot(named: "C10-Processing-Recovery")
        scrollAndTap(app.buttons["Try Transcript Again"], in: app)

        XCTAssertTrue(app.staticTexts["Turning a recording into a lesson."].waitForExistence(timeout: 3))
        scrollAndTap(app.buttons["Review Draft"], in: app)
        XCTAssertTrue(app.staticTexts["Keep their words true."].waitForExistence(timeout: 3))
        keepScreenshot(named: "C05-Transcript-Review")
        scrollAndTap(app.buttons["Approve Transcript"], in: app)

        XCTAssertTrue(app.staticTexts["Gather what they use."].waitForExistence(timeout: 3))
        keepScreenshot(named: "C06-Materials-Review")
        scrollAndTap(app.buttons["Approve Materials"], in: app)

        XCTAssertTrue(app.staticTexts["Shape the lesson together."].waitForExistence(timeout: 3))
        keepScreenshot(named: "C07-Steps-Editor")
        scrollAndTap(app.buttons["Approve Steps"], in: app, maxSwipes: 10)

        XCTAssertTrue(app.staticTexts["Ready for your family."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Cover photo 2"].waitForExistence(timeout: 3))
        app.buttons["Cover photo 2"].tap()
        keepScreenshot(named: "C08-Cover-Sharing")
        scrollAndTap(app.buttons["Publish to Family Space"], in: app, maxSwipes: 8)

        XCTAssertTrue(app.staticTexts["A family skill lives on."].waitForExistence(timeout: 3))
        keepScreenshot(named: "C09-Publish-Success")
        XCTAssertTrue(app.buttons["View Lesson"].exists)
        XCTAssertTrue(app.buttons["Record Another Skill"].exists)
        app.buttons["View Lesson"].tap()
        XCTAssertTrue(app.staticTexts["Grandma's Dumplings"].waitForExistence(timeout: 3))
        scrollAndTap(app.buttons["Continue Learning"], in: app)
        XCTAssertTrue(app.staticTexts["Gather what you need."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["All-purpose flour"].exists)
        scrollAndTap(app.buttons["Start Step 1"], in: app)
        XCTAssertTrue(app.staticTexts["Mix the dough"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Add water slowly while mixing."].exists)
        keepScreenshot(named: "I01-Published-Lesson-Learning")
        for _ in 0..<4 { scrollAndTap(app.buttons["Mark Step Complete"], in: app) }
        XCTAssertTrue(app.staticTexts["Show what you learned."].waitForExistence(timeout: 5))
        scrollAndTap(app.buttons["Use Sample Photo"], in: app)
        scrollAndTap(app.buttons["Submit Practice"], in: app)
        scrollAndTap(app.buttons["Share with Family"], in: app)
        scrollAndTap(app.buttons["Finish Lesson"], in: app)
        XCTAssertTrue(app.staticTexts["You carried it forward."].waitForExistence(timeout: 5))
        scrollAndTap(app.buttons["Back to Learn"], in: app)
        app.buttons["Family"].tap()
        for _ in 0..<4 where !app.staticTexts["shared a practice for Grandma's Dumplings."].isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["shared a practice for Grandma's Dumplings."].exists)
        keepScreenshot(named: "I03-Published-Practice-Family-Activity")
        app.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["My Profile"].waitForExistence(timeout: 5))
        scrollAndTap(app.buttons["Edit Profile"], in: app)
        let field = app.textFields["Profile name"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        let original = field.value as? String ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: original.count))
        field.typeText("Alex Morgan")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Alex Morgan"].waitForExistence(timeout: 3))
        for _ in 0..<5 where !app.buttons["Settings"].isHittable { app.swipeDown() }
        app.buttons["Settings"].firstMatch.tap()
        scrollAndTap(app.buttons["Manage My Data, Export and removal controls"], in: app)
        scrollAndTap(app.buttons["Prepare Export"], in: app)
        app.alerts.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["Save or Share Export"].waitForExistence(timeout: 3))
        keepScreenshot(named: "I04-Real-Local-Data-Export")
    }

    @MainActor
    func testLibraryLearningProgressPersistsAcrossRelaunch() throws {
        let app = makeLibraryApp(state: "populated")
        app.launchArguments += ["-resetLearn", "-resetFamilyProfile"]
        app.launch()
        app.buttons["Grandma’s Apple Pie"].tap()
        scrollAndTap(app.buttons["Continue Learning"], in: app)
        XCTAssertTrue(app.staticTexts["Gather what you need."].waitForExistence(timeout: 3))
        scrollAndTap(app.buttons["Start Step 1"], in: app)
        scrollAndTap(app.buttons["Mark Step Complete"], in: app)
        XCTAssertTrue(app.staticTexts["Peel the apples"].waitForExistence(timeout: 3))
        app.terminate()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-libraryFixture", "populated"]
        app.launch()
        app.buttons["Grandma’s Apple Pie"].tap()
        XCTAssertTrue(app.staticTexts["1 completed"].waitForExistence(timeout: 3))
        scrollAndTap(app.buttons["Continue Learning"], in: app)
        XCTAssertTrue(app.staticTexts["Peel the apples"].waitForExistence(timeout: 3))
        keepScreenshot(named: "I02-Restored-Learning-Checkpoint")
    }

    @MainActor
    func testRecordingGuidanceStaysInsideTheScreen() throws {
        let app = makeCaptureApp()
        app.launch()

        XCTAssertTrue(app.buttons["Record Now"].waitForExistence(timeout: 5))
        app.buttons["Record Now"].tap()

        let guidance = app.staticTexts["Clear, close audio helps your family review the original voice later."]
        XCTAssertTrue(guidance.waitForExistence(timeout: 3))
        let screenFrame = app.windows.firstMatch.frame
        XCTAssertGreaterThanOrEqual(guidance.frame.minX, screenFrame.minX + 16)
        XCTAssertLessThanOrEqual(guidance.frame.maxX, screenFrame.maxX - 16)
    }

    @MainActor
    func testRealVideoImportAndManualReview() throws {
        let app = makeCaptureApp()
        app.launch()
        XCTAssertTrue(app.buttons["Import a Video"].waitForExistence(timeout: 5))
        app.buttons["Import a Video"].tap()
        let video = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(video.waitForExistence(timeout: 60), app.debugDescription)
        video.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        if app.buttons["Add"].waitForExistence(timeout: 1) { app.buttons["Add"].tap() }
        XCTAssertTrue(app.staticTexts["Tell us what this skill means."].waitForExistence(timeout: 10))
        let title = app.textFields["Skill title"]
        title.tap(); title.typeText("Fold a paper bookmark")
        let maker = app.textFields["Maker"]
        maker.tap(); maker.typeText("Alex")
        let language = app.textFields["Spoken language"]
        language.tap(); language.typeText("English")
        scrollAndTap(app.buttons["Create Lesson Draft"], in: app)
        scrollAndTap(app.buttons["Review Draft"], in: app)
        scrollAndTap(app.buttons["Edit Transcript"], in: app)
        let transcript = app.textViews.firstMatch
        XCTAssertTrue(transcript.waitForExistence(timeout: 3))
        transcript.tap(); transcript.typeText("Fold the top corner down carefully.")
        scrollAndTap(app.buttons["Finish Editing"], in: app)
        scrollAndTap(app.buttons["Approve Transcript"], in: app)
        scrollAndTap(app.buttons["Approve Materials"], in: app)
        scrollAndTap(app.buttons["Approve Steps"], in: app)
        scrollAndTap(app.buttons["Publish to Family Space"], in: app, maxSwipes: 10)
        app.buttons["View Lesson"].tap()
        scrollAndTap(app.buttons["Continue Learning"], in: app)
        scrollAndTap(app.buttons["Start Step 1"], in: app)
        XCTAssertTrue(app.staticTexts["Fold a paper bookmark"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Source Video Player").firstMatch.waitForExistence(timeout: 5))
        keepScreenshot(named: "I05-Real-Imported-Video-Player")
    }

    @MainActor
    func testLocalDataResetReturnsToWelcome() throws {
        let app = makeProfileApp(route: "deletion")
        app.launch()
        let confirmation = app.textFields["Type DELETE to continue"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        scrollAndTap(confirmation, in: app)
        confirmation.typeText("DELETE")
        scrollAndTap(app.buttons["Delete All Local Data"], in: app)
        XCTAssertTrue(app.staticTexts["Keep family know-how alive."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testLargeTextCoreNavigation() throws {
        let app = makeLibraryApp(state: "empty")
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        scrollAndTap(app.buttons["Record First Skill"], in: app, maxSwipes: 10)
        XCTAssertTrue(app.staticTexts["Preserve a family skill."].waitForExistence(timeout: 5))
        let importButton = app.buttons["Import a Video"]
        for _ in 0..<10 where !importButton.isHittable { app.swipeUp() }
        XCTAssertTrue(importButton.isHittable)
        XCTAssertGreaterThanOrEqual(importButton.frame.height, 44)
        keepScreenshot(named: "I06-Accessibility-Large-Text-Capture")
    }

    @MainActor
    func testLearnCoreJourney() throws {
        let app = makeLearnApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["Continue learning, together."].waitForExistence(timeout: 5))
        keepScreenshot(named: "L01-Learn-Dashboard")
        scrollAndTap(app.buttons["Start Lesson"], in: app)
        XCTAssertTrue(app.staticTexts["Gather what you need."].waitForExistence(timeout: 3))
        app.buttons["6 crisp apples"].tap()
        keepScreenshot(named: "L02-Materials-Checklist")
        scrollAndTap(app.buttons["Start Step 1"], in: app)

        XCTAssertTrue(app.staticTexts["Chill the dough"].waitForExistence(timeout: 3))
        keepScreenshot(named: "L03-Step-Player")
        scrollAndTap(app.buttons["Ask About This Step"], in: app)
        XCTAssertTrue(app.staticTexts["Ask from the family lesson."].waitForExistence(timeout: 3))
        app.buttons["Why leave gaps in the lattice?"].tap()
        XCTAssertTrue(app.staticTexts["Leave small gaps in the lattice so steam can escape and the crust stays crisp."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Grandma’s note · Step 6"].exists)
        keepScreenshot(named: "L04-Lesson-QA")
        app.buttons["Back to Step"].tap()

        for _ in 0..<8 {
            scrollAndTap(app.buttons["Mark Step Complete"], in: app)
        }
        XCTAssertTrue(app.staticTexts["Show what you learned."].waitForExistence(timeout: 3))
        keepScreenshot(named: "L05-Practice-Submission")
        scrollAndTap(app.buttons["Use Sample Photo"], in: app)
        scrollAndTap(app.buttons["Submit Practice"], in: app)

        XCTAssertTrue(app.staticTexts["A private first try."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Only you can see this practice."].exists)
        keepScreenshot(named: "L06-Practice-Feedback")
        scrollAndTap(app.buttons["Share with Family"], in: app)
        scrollAndTap(app.buttons["Finish Lesson"], in: app)

        XCTAssertTrue(app.staticTexts["You carried it forward."].waitForExistence(timeout: 3))
        keepScreenshot(named: "L07-Lesson-Completion")
        scrollAndTap(app.buttons["View Learning History"], in: app)
        XCTAssertTrue(app.staticTexts["Learning History"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Completed · Pass 1"].exists)
        keepScreenshot(named: "L08-Learning-History")
    }

    @MainActor
    func testJoinFamilySpaceJourney() throws {
        let app = makeCleanApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["Keep family know-how alive."].waitForExistence(timeout: 5))
        app.buttons["I have an invite"].tap()
        XCTAssertTrue(app.staticTexts["Learn together, from anywhere."].waitForExistence(timeout: 5))

        let codeField = app.textFields["Invitation code"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 2))
        codeField.tap()
        codeField.typeText("echo26")

        XCTAssertTrue(app.staticTexts["The Carter Family"].waitForExistence(timeout: 4))
        let joinButton = app.buttons["Join Family Space"]
        XCTAssertTrue(joinButton.isEnabled)
        joinButton.tap()

        XCTAssertTrue(app.staticTexts["You're part of the family."].waitForExistence(timeout: 2))
    }

    @MainActor
    func testCaptureApprovedOnboardingScreens() throws {
        let app = makeCleanApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["Keep family know-how alive."].waitForExistence(timeout: 5))
        keepScreenshot(named: "01-Welcome")

        tap(
            app.buttons["Get Started"],
            until: app.staticTexts["From memory to lesson."]
        )
        keepScreenshot(named: "02-How-It-Works")

        tap(
            app.buttons["Continue"],
            until: app.staticTexts["Your family stories stay private."]
        )
        keepScreenshot(named: "03-Privacy")

        tap(
            app.buttons["Set Up My Space"],
            until: app.staticTexts["Who will you learn with?"]
        )
        keepScreenshot(named: "04-Family-Space-Choice")

        tap(
            app.buttons["Create a Family Space"],
            until: app.textFields["Family Space name"]
        )
        let screenshotNameField = app.textFields["Family Space name"]
        screenshotNameField.tap()
        screenshotNameField.typeText("The Carter Family")
        if app.keyboards.buttons["Done"].exists {
            app.keyboards.buttons["Done"].tap()
        }
        keepScreenshot(named: "05-Create-Family-Space")

        tap(
            app.buttons["Back"],
            until: app.staticTexts["Who will you learn with?"]
        )
        tap(
            app.buttons["Join a Family Space"],
            until: app.textFields["Invitation code"]
        )
        let screenshotCodeField = app.textFields["Invitation code"]
        screenshotCodeField.tap()
        screenshotCodeField.typeText("ECHO26")
        XCTAssertTrue(app.staticTexts["The Carter Family"].waitForExistence(timeout: 2))
        keepScreenshot(named: "06-Join-Family-Space")
    }

    @MainActor
    func testFamilyInvitationAndPermissionsJourney() throws {
        let app = makeFamilyApp(route: nil)
        app.launch()

        XCTAssertTrue(app.staticTexts["Skills live longer when we keep them together."].waitForExistence(timeout: 5))
        app.buttons["Invite Family"].tap()
        XCTAssertTrue(app.staticTexts["Members"].waitForExistence(timeout: 3))

        app.buttons["Manage Rose Carter"].tap()
        XCTAssertTrue(app.staticTexts["Rose’s access"].waitForExistence(timeout: 3))
        scrollAndTap(app.buttons["Save Changes"], in: app)
        XCTAssertTrue(app.staticTexts["Members"].waitForExistence(timeout: 3))

        scrollAndTap(app.buttons["Invite a Member"], in: app, maxSwipes: 12)
        XCTAssertTrue(app.staticTexts["Bring someone into your family story."].waitForExistence(timeout: 3))
        let email = app.textFields["Email address"]
        email.tap()
        email.typeText("alex@example.com")
        if app.keyboards.buttons["return"].exists { app.keyboards.buttons["return"].tap() }
        scrollAndTap(app.buttons["Send Invitation"], in: app, maxSwipes: 10)
        XCTAssertTrue(app.staticTexts["alex@example.com"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testProfilePrivacyAndDataJourney() throws {
        let app = makeProfileApp(route: "profile")
        app.launch()

        XCTAssertTrue(app.staticTexts["My Profile"].waitForExistence(timeout: 5))
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 3))
        scrollAndTap(app.buttons["Privacy & Permissions, Camera, microphone, photos"], in: app)
        XCTAssertTrue(app.staticTexts["Privacy & Permissions"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Questions, personal progress, and draft lessons are private by default."].exists)
        app.buttons["Back to Settings"].tap()
        scrollAndTap(app.buttons["Manage My Data, Export and removal controls"], in: app)
        XCTAssertTrue(app.staticTexts["Manage My Data"].waitForExistence(timeout: 3))
        scrollAndTap(app.buttons["Review Account Deletion"], in: app, maxSwipes: 10)
        XCTAssertTrue(app.staticTexts["Before you delete your account."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Delete My Account"].exists)
        XCTAssertFalse(app.buttons["Delete My Account"].isEnabled)
    }

    @MainActor
    func testCaptureFamilyProfileScreens() throws {
        let screens: [(String, String, Bool)] = [
            ("overview", "Skills live longer when we keep them together.", false),
            ("members", "Members", false), ("invite", "Bring someone into your family story.", false),
            ("permissions", "Rose’s access", false), ("activity", "Family Activity", false),
            ("maker", "Grandma Rose", false), ("profile", "My Profile", true),
            ("settings", "Settings", true), ("storage", "Storage", true),
            ("notifications", "Notifications", true), ("privacy", "Privacy & Permissions", true),
            ("data", "Manage My Data", true), ("deletion", "Before you delete your account.", true),
            ("help", "How can we help?", true)
        ]
        for (index, screen) in screens.enumerated() {
            let app = screen.2 ? makeProfileApp(route: screen.0) : makeFamilyApp(route: screen.0 == "overview" ? nil : screen.0)
            app.launch()
            XCTAssertTrue(app.staticTexts[screen.1].waitForExistence(timeout: 5), "Missing \(screen.0)")
            keepScreenshot(named: String(format: "F%02d-%@", index + 1, screen.0))
            app.terminate()
        }
    }

    private func makeCleanApp() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-nativeOnlineServices", "-resetOnboarding", "-resetPublishedLessons", "-resetLearn", "-resetFamilyProfile", "-icloudAvailable", "1"]
        return app
    }

    private func makeLibraryApp(state: String) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-resetPublishedLessons", "-resetLearn", "-libraryFixture", state]
        return app
    }

    private func makeCaptureApp() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-openCapture", "-resetCapture", "-resetPublishedLessons", "-resetLearn", "-libraryFixture", "populated"]
        return app
    }

    private func makeLearnApp() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-openLearn", "-resetLearn", "-libraryFixture", "populated"]
        return app
    }

    private func makeFamilyApp(route: String?) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-openFamily", "-resetFamilyProfile", "-libraryFixture", "populated"]
        if let route { app.launchArguments += ["-familyRoute", route] }
        return app
    }

    private func makeProfileApp(route: String?) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-openLibrary", "-openProfile", "-resetFamilyProfile", "-libraryFixture", "populated"]
        if let route { app.launchArguments += ["-familyRoute", route] }
        return app
    }

    private func keepScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tap(_ element: XCUIElement, until destination: XCUIElement) {
        element.tap()
        if !destination.waitForExistence(timeout: 2) {
            XCTAssertTrue(element.waitForExistence(timeout: 2))
            element.tap()
        }
        XCTAssertTrue(destination.waitForExistence(timeout: 4))
    }

    private func scrollAndTap(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 6) {
        for _ in 0..<maxSwipes where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 2))
        XCTAssertTrue(element.isHittable)
        element.tap()
    }
}
