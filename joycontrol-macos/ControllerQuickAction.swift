//
//  ControllerQuickAction.swift
//  joycontrol-macos
//
//  Created by Joey Jacobs on 2/25/21.
//

import Foundation

struct ControllerQuickActionStep {
    var durationInMs: Int
    var stickAndDirection: (ControllerButton, StickDirection)?
    var buttons: [ControllerButton] = []
}

private func insertWaitsAfterEachStep(waitInMs: Int, _ steps: [ControllerQuickActionStep]) -> [ControllerQuickActionStep] {
    steps.flatMap { step in
        [step, .init(durationInMs: waitInMs)]
    }
}

struct ControllerQuickActionTopLevel: Identifiable {
    // swiftlint:disable:next identifier_name
    var id = UUID()
    var name: String
    var children: [ControllerQuickAction]
}

/// Automated controller input
struct ControllerQuickAction: Identifiable {
    // swiftlint:disable:next identifier_name
    var id = UUID()
    var name: String
    var steps: [ControllerQuickActionStep] = []
}

private let kPokemonSwordShieldMoveBikeInCircle = ControllerQuickAction(name: "Move Bike in Circle", steps: insertWaitsAfterEachStep(waitInMs: 80, [
    .init(durationInMs: 80, stickAndDirection: (.leftStick, .bottom)),
    .init(durationInMs: 80, stickAndDirection: (.leftStick, .bottomLeft)),
    .init(durationInMs: 80, stickAndDirection: (.leftStick, .left)),
    .init(durationInMs: 80, stickAndDirection: (.leftStick, .topLeft)),
    .init(durationInMs: 80, stickAndDirection: (.leftStick, .top)),
    .init(durationInMs: 80, stickAndDirection: (.leftStick, .topRight)),
    .init(durationInMs: 80, stickAndDirection: (.leftStick, .right)),
    .init(durationInMs: 80, stickAndDirection: (.leftStick, .bottomRight))
]))

let kQuickActions = [
    ControllerQuickActionTopLevel(name: "Pokemon Sword/Shield", children:
        [
            kPokemonSwordShieldMoveBikeInCircle,
            ControllerQuickAction(name: "Move Bike in Circle 10x", steps: Array((1 ... 10).map { _ in kPokemonSwordShieldMoveBikeInCircle.steps }.joined()))
        ])
]
