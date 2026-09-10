import CoreGraphics
import MomoCore
import Testing

@testable import MomoCharacter

// MARK: - The prop wiring (TASK-028 R9; 04 §6.1/§2.3; TASK-026 flips)

/// Each prop renders ONLY inside its owning family's windows — food during
/// the eat family, the blanket during settling/adjust, the sparkles during
/// moments and the play payoff — and every other clip leaves all four at
/// rest (the TASK-026 "props inert" pins, now scoped "inert WHEN UNUSED").
/// The pose-level applied path and the LOD gate close the loop.
struct MomoReactionPropsTests {

    /// All four props at rest.
    private func propsRest(_ motion: MomoReactionMotion) -> Bool {
        motion.food == .rest && motion.blanket == .rest
            && motion.sparkleA == .rest && motion.sparkleB == .rest
    }

    // MARK: The choreography's prop windows

    @Test("The food prop lives exactly inside the meal's bite windows")
    func foodWindows() {
        // The meal: bites at (0.4, 0.8), (1.4, 0.8), (2.4, 0.8). Mid-bite
        // the food bobs; between bites it rests.
        let midBite = MomoReactionChoreography.motion(
            for: .eating, elapsed: 0.8, duration: 3.2, holdSeconds: nil,
            deepened: false, context: ReactionFixturesContext.relaxed)
        #expect(midBite.food != .rest)
        #expect(midBite.mouthWeights!.eat > 0)
        let between = MomoReactionChoreography.motion(
            for: .eating, elapsed: 1.2, duration: 3.2, holdSeconds: nil,
            deepened: false, context: ReactionFixturesContext.relaxed)
        #expect(between.food == .rest)
        #expect(propsRest(between))
        // The nibble and the sleepy nibbles are the same family.
        let nibble = MomoReactionChoreography.motion(
            for: .nibble, elapsed: 0.7, duration: 1.6, holdSeconds: nil,
            deepened: false, context: ReactionFixturesContext.relaxed)
        #expect(nibble.food != .rest)
        let sleepy = MomoReactionChoreography.motion(
            for: .sleepyNibbles, elapsed: 1.0, duration: 3.5,
            holdSeconds: nil, deepened: false,
            context: ReactionFixturesContext.relaxed)
        #expect(sleepy.food != .rest)
    }

    @Test("The blanket prop lives in settling and the blanket adjust only")
    func blanketWindows() {
        // The adjust: the blanket nudges; the food stays out.
        let adjust = MomoReactionChoreography.motion(
            for: .blanketAdjust, elapsed: 0.7, duration: 1.5,
            holdSeconds: nil, deepened: false,
            context: ReactionFixturesContext.relaxed)
        #expect(adjust.blanket != .rest)
        #expect(adjust.food == .rest)
        // The settle: the blanket drifts over the sleeping form in its
        // final phase (2.2 → 3.0), rests during the yawn.
        let settling = MomoHandshakeChoreography.settleMotion(elapsed: 2.8)
        #expect(settling.blanket != .rest)
        let yawn = MomoHandshakeChoreography.settleMotion(elapsed: 1.0)
        #expect(yawn.blanket == .rest)
        #expect(propsRest(yawn))
    }

    @Test("The sparkles live in the play payoff and the moments only")
    func sparkleWindows() {
        // The payoff rings both sparkles.
        let payoff = MomoHandshakeChoreography.payoffMotion(
            elapsed: 1.0, yawn: false)
        #expect(payoff.sparkleA != .rest)
        #expect(payoff.sparkleB != .rest)
        #expect(payoff.food == .rest && payoff.blanket == .rest)
        // The quest sparkle rides the A sparkle.
        let quest = MomoMoments.motion(for: .questCompleted, elapsed: 0.5)
        #expect(quest.sparkleA != .rest)
        #expect(quest.sparkleB == .rest)
        // The celebration rings both.
        let celebration = MomoMoments.motion(
            for: .bondStageReached(.soulCompanions), elapsed: 0.9)
        #expect(celebration.sparkleA != .rest)
        #expect(celebration.sparkleB != .rest)
    }

    /// Every non-prop clip leaves all four props at rest for its WHOLE
    /// trajectory (the "inert WHEN UNUSED" flip, swept).
    @Test("Touch clips and greetings never touch a prop (swept)")
    func touchClipsLeavePropsAtRest() {
        let propless: [MomoReactionKey] = [
            .tapHead, .tapBelly, .tap, .doubleTap,
            .longPressHead, .longPressBelly, .longPress,
            .strokeHead, .strokeBelly, .stroke,
            .stir, .politelyFull, .gentleDecline, .cheer, .decline,
        ]
        for key in propless {
            for t in samples(until: 2.0, count: 40) {
                let motion = MomoReactionChoreography.motion(
                    for: key, elapsed: t, duration: 1.2, holdSeconds: 0.5,
                    deepened: false, context: ReactionFixturesContext.relaxed)
                #expect(propsRest(motion),
                        "\(key.rawValue) animated a prop at t=\(t)")
            }
        }
        // The greetings and the wake stretch are propless too.
        for kind in [GreetingKind.freshMorning, .welcomeBack, .missedYou,
                     .nightGlance] {
            for t in samples(until: 2.0, count: 40) {
                let motion = MomoMoments.motion(
                    for: .greeting(kind), elapsed: t)
                #expect(propsRest(motion))
            }
        }
        for t in samples(until: MomoHandshakeChoreography.wakeDurationSeconds,
                         count: 40) {
            #expect(propsRest(
                MomoHandshakeChoreography.wakeMotion(elapsed: t)))
        }
        // The follow and invite phases of play touch no prop.
        for t in samples(until: MomoHandshakeChoreography.inviteSeconds,
                         count: 20) {
            #expect(propsRest(
                MomoHandshakeChoreography.inviteMotion(elapsed: t)))
        }
        #expect(propsRest(MomoHandshakeChoreography.followMotion(
            fingertipOffset: CGPoint(x: 120, y: -40))))
    }

    // MARK: The pose-level applied path (prop anchors in the layer tree)

    /// A meal mid-bite flows director → overlay → model → pose: the food
    /// prop renders about its anchor and the mouth takes the eat weight.
    @Test("The applied path renders the food through the director overlay")
    func appliedFoodPath() {
        var state = MomoDirectorState(
            displayState: ReactionFixtures.displayState(activity: .eating))
        state.apply(ReactionFixtures.plan(ReactionKeys.eating, at: 0.5))
        let overlay = state.overlay(at: 1.3) // mid first bite
        #expect(overlay.food != .rest)

        let model = RigMotionModel()
        let pose = model.pose(
            at: 1.3,
            displayState: ReactionFixtures.displayState(activity: .eating),
            reactionMotion: overlay)
        #expect(pose.food != .rest)
        #expect(pose.food.transform.translation.y < 0) // bobbed up
        #expect(pose.mouth.eat > 0)

        // The blanket path: the adjust clip moves ONLY the blanket prop.
        var adjust = MomoDirectorState(displayState: ReactionFixtures.content)
        adjust.apply(ReactionFixtures.plan(ReactionKeys.blanketAdjust, at: 0.5))
        let adjustPose = model.pose(
            at: 1.2, displayState: ReactionFixtures.content,
            reactionMotion: adjust.overlay(at: 1.2))
        #expect(adjustPose.blanket != .rest)
        #expect(adjustPose.food == .rest)
        #expect(adjustPose.sparkleA == .rest && adjustPose.sparkleB == .rest)
    }

    /// The LOD gate: a tier without the prop channels renders the rest
    /// pose for that prop even while the choreography requests it.
    @Test("Disabling a prop channel gates that prop out of the pose")
    func propChannelGating() {
        let overlay = MomoReactionChoreography.motion(
            for: .eating, elapsed: 0.8, duration: 3.2, holdSeconds: nil,
            deepened: false, context: ReactionFixturesContext.relaxed)
        let gated = RigMotionModel(
            enabledChannels: RigChannel.all.subtracting([.propFood, .mouthPose]))
        let pose = gated.pose(
            at: 0.8,
            displayState: ReactionFixtures.displayState(activity: .eating),
            reactionMotion: overlay)
        #expect(pose.food == .rest)
        #expect(pose.mouth == .neutral)
        // The ungated twin renders both.
        let open = RigMotionModel().pose(
            at: 0.8,
            displayState: ReactionFixtures.displayState(activity: .eating),
            reactionMotion: overlay)
        #expect(open.food != .rest)
        #expect(open.mouth.eat > 0)
    }

    // MARK: The clip table's channel rows agree with the props

    @Test("Only the eat-family rows carry the prop channels in their spec")
    func specChannelAgreement() {
        #expect(MomoReactionClips.spec(for: .eating).channels.contains(.propFood))
        #expect(MomoReactionClips.spec(for: .nibble).channels.contains(.propFood))
        #expect(
            MomoReactionClips.spec(for: .sleepyNibbles).channels.contains(.propFood))
        #expect(
            MomoReactionClips.spec(for: .blanketAdjust).channels.contains(.propBlanket))
        #expect(
            MomoReactionClips.spec(for: .settling).channels.contains(.propBlanket))
        for key in MomoReactionKey.allCases
        where key != .eating && key != .nibble && key != .sleepyNibbles {
            #expect(
                !MomoReactionClips.spec(for: key).channels.contains(.propFood),
                "\(key.rawValue) claims the food prop")
        }
        for key in MomoReactionKey.allCases
        where key != .blanketAdjust && key != .settling {
            #expect(
                !MomoReactionClips.spec(for: key).channels.contains(.propBlanket),
                "\(key.rawValue) claims the blanket prop")
        }
        for key in MomoReactionKey.allCases {
            let spec = MomoReactionClips.spec(for: key)
            #expect(!spec.channels.contains(.propSparkleA))
            #expect(!spec.channels.contains(.propSparkleB))
        }
    }
}

/// The frozen context the choreography windows use (the calm baseline).
private enum ReactionFixturesContext {
    static let relaxed = MomoReactionContext(
        moodBand: .content, energyBand: .relaxed, bondStage: .bestFriends,
        wakefulness: .awake)
}
