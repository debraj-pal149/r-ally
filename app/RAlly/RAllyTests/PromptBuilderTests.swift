import Foundation
import Testing
@testable import RAlly

struct PromptBuilderTests {
    @Test func fillsPersonaSlots() {
        let p = Persona.named(.southpaw)
        let sys = PromptBuilder.system(persona: p)
        #expect(sys.contains("The Southpaw"))
        #expect(sys.contains("{persona_name}") == false)
        let user = PromptBuilder.user(.init(
            activity: .running, elapsed: 1300, progressLabel: "3.4 km of 5.0 km goal (68%)",
            snapshot: "pace slipping", prompt: "Don't let me negotiate with myself",
            athleteName: "Deb", intensityMaximum: false, recent: ["Go"], persona: p
        ))
        #expect(user.contains("Deb"))
        #expect(user.contains("running"))
    }
}

struct FallbackLinesTests {
    @Test func banksAreLarge() {
        for p in Persona.ID.allCases {
            for k in TriggerKind.allCases {
                let lines = FallbackLines.all(persona: p, kind: k)
                #expect(lines.count >= 40)
            }
        }
    }
}

struct SpeechCoachTests {
    @Test func coachTextAddsCadence() {
        #expect(SpeechEngine.coachText("Kid stay in it") == "Kid, stay in it.")
        #expect(SpeechEngine.breathChunks("Hold.. Now go.").count == 2)
    }
}
