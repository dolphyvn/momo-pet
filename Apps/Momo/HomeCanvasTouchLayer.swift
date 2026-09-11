import SwiftUI
import MomoCharacter
import MomoKit
import MomoCore

// MARK: - HomeCanvasTouchSurface — the Home canvas's gesture layer (TASK-034
// R2 + R9; 04 §6.1; 03-ux-architecture §5.1)

/// The canvas's touch surface: ONE clear, full-region gesture target laid
/// over the rig (coextensive with the `home.canvas` accessibility element —
/// INV-2's no-dead-zones reading: every touch in the canvas region lands in
/// a zone, because the zone rule is a total function of y). All decisions
/// are delegated to MomoKit's pure touch vocabulary (`CanvasTouchLaws` /
/// `CanvasZoneHitTest` / `CanvasTouchClassifier` / `CanvasTapSequence`);
/// what remains here is deliberately mechanical, mirroring the app model's
/// executor split.
///
/// **The recognizer.** A single `DragGesture(minimumDistance: 0)` captures
/// the full touch lifecycle — its first `onChanged` is the physical
/// touch-down instant (what §6.1's press-length input requires, and what
/// native tap recognizers cannot report), its `onEnded` the lift. Stroke
/// and long-press classify at the lift; a tap-speed touch defers through
/// the double-tap window (`CanvasTapSequence` + one delayed dispatch), so
/// a single tap fires ~0.35 s after its lift — the standard tap/double-tap
/// disambiguation cost.
///
/// **The cancellation seam (R9; FIX1-NOTE-1).** The system can take a
/// touch away mid-gesture (notification pull-down, control center, an
/// incoming-call banner): `onEnded` never fires. `@GestureState` — whose
/// documented contract is resetting on gesture end INCLUDING cancellation —
/// carries the seam: the flag's false transition while a touch is still
/// open resolves the press exactly like a release (idempotent
/// `touchEnded`), and drops any parked tap so a stolen touch stream never
/// speaks for a gesture that never completed. The app model additionally
/// force-closes a stale open touch if a new `touchBegan` ever arrives, so
/// the open-touch invariant cannot wedge even if the reset went unobserved.
@MainActor
struct HomeCanvasTouchSurface: View {

    /// The composed stage side (the square the rig draws in, centered in
    /// the region) — the y-mapping's denominator.
    let stageSide: CGFloat

    @Environment(MomoAppModel.self) private var appModel

    /// The `@GestureState` seam: true while the gesture is live; its reset
    /// to false is the cancellation signal (see the type header).
    @GestureState private var pressActive = false

    /// Whether a touch is open in THIS layer (the seam's discriminator: a
    /// normal lift runs `onEnded` first, so the reset finds nothing to do).
    @State private var touchIsDown = false

    /// The one live touch's classification inputs.
    @State private var downStamp: Double = 0
    @State private var startLocation: CGPoint = .zero
    @State private var maxMovementGrid: Double = 0
    @State private var zoneAtDown: TouchZone = .head

    /// The tap/double-tap pairing state and its delayed dispatch.
    @State private var tapSequence = CanvasTapSequence()
    @State private var pendingTap: Task<Void, Never>?

    var body: some View {
        GeometryReader { proxy in
            // The stage square is centered in the region (the rig's own
            // centering), so the zone rule's grid y reads from the square's
            // top edge. Taps in the region's padding above/below the square
            // still classify (the rule is total), exactly INV-2's reading.
            let stageTop = max(0, (proxy.size.height - stageSide) / 2)
            Color.clear
                .contentShape(Rectangle())
                .gesture(dragGesture(stageTop: stageTop))
        }
        .onChange(of: pressActive) { _, active in
            guard !active, touchIsDown else { return }
            resolveAsCancellation()
        }
    }

    // MARK: The gesture pipeline

    private func dragGesture(stageTop: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($pressActive) { _, state, _ in state = true }
            .onChanged { value in
                guard !touchIsDown else {
                    noteMovement(value)
                    return
                }
                touchIsDown = true
                startLocation = value.startLocation
                maxMovementGrid = 0
                zoneAtDown = zone(at: value.startLocation, stageTop: stageTop)
                downStamp = appModel.touchBegan(zone: zoneAtDown)
                noteMovement(value)
            }
            .onEnded { value in
                guard touchIsDown else { return }
                touchIsDown = false
                noteMovement(value)
                let upStamp = appModel.touchEnded()
                completeTouch(upAt: upStamp)
            }
    }

    /// Movement in grid units (the classifier's stroke input): the running
    /// max over the touch's samples, so a wander-out-and-back still reads
    /// as a stroke.
    private func noteMovement(_ value: DragGesture.Value) {
        let movementGrid = hypot(
            value.translation.width,
            value.translation.height
        ) / stageSide * CanvasTouchLaws.stageGridSide
        maxMovementGrid = max(maxMovementGrid, movementGrid)
    }

    /// The lift's classification: stroke or long-press from the touch
    /// alone; a tap-speed touch defers through the pairing state, whose
    /// immediate answer is a double-tap and whose parked tap dispatches
    /// when its window matures unclaimed.
    private func completeTouch(upAt: Double) {
        if let gesture = CanvasTouchClassifier.completedGesture(
            holdSeconds: upAt - downStamp,
            maxMovementGrid: maxMovementGrid,
            zone: zoneAtDown
        ) {
            dispatch(gesture)
            return
        }
        let (successor, paired) = tapSequence.recording(zone: zoneAtDown, upAt: upAt)
        tapSequence = successor
        if let paired {
            pendingTap?.cancel()
            pendingTap = nil
            dispatch(paired)
        } else {
            scheduleMaturation(afterTapAt: upAt)
        }
    }

    private func scheduleMaturation(afterTapAt upAt: Double) {
        let window = CanvasTouchLaws.doubleTapWindowSeconds
        pendingTap = Task {
            try? await Task.sleep(for: .seconds(window))
            guard !Task.isCancelled else { return }
            let (successor, matured) = tapSequence.maturing(now: upAt + window)
            tapSequence = successor
            if let matured {
                dispatch(matured)
            }
        }
    }

    /// The FIX1-NOTE-1 seam: the system took the touch away — resolve the
    /// press exactly like a release (idempotent close) and drop the parked
    /// tap (a cancelled stream never speaks for an uncompleted gesture).
    private func resolveAsCancellation() {
        touchIsDown = false
        _ = appModel.touchEnded()
        pendingTap?.cancel()
        pendingTap = nil
        tapSequence = tapSequence.resetting()
        maxMovementGrid = 0
    }

    /// The §6.1 rows → the engine's interaction vocabulary. The double-tap
    /// carries no zone (its one row for both zones); every other gesture
    /// carries the zone it happened in.
    private func dispatch(_ gesture: CanvasGesture) {
        switch gesture {
        case .tap(let zone):
            appModel.interact(.pat(gesture: .tap, zone: zone))
        case .doubleTap:
            appModel.interact(.pat(gesture: .doubleTap, zone: nil))
        case .longPress(let zone):
            appModel.interact(.pat(gesture: .longPress, zone: zone))
        case .stroke(let zone):
            appModel.interact(.pat(gesture: .stroke, zone: zone))
        }
    }

    /// The pure y → zone mapping at a surface-local point (04 §2.3's rule
    /// over the stage square's top edge).
    private func zone(at point: CGPoint, stageTop: CGFloat) -> TouchZone {
        let gridY = (Double(point.y) - Double(stageTop))
            / Double(stageSide) * CanvasTouchLaws.stageGridSide
        return CanvasZoneHitTest.zone(normalizedY: gridY)
    }
}
