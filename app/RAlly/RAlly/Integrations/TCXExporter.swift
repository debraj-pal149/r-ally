import Foundation

enum TCXExporter {
    static func tcx(session: WorkoutSessionRecord) -> Data {
        let df = ISO8601DateFormatter()
        let start = df.string(from: session.startedAt)
        let sport = session.activity == .cycling ? "Biking" : session.activity == .swimming ? "Other" : "Running"
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
          <Activities>
            <Activity Sport="\(sport)">
              <Id>\(start)</Id>
              <Lap StartTime="\(start)">
                <TotalTimeSeconds>\(Int(session.durationSec))</TotalTimeSeconds>
                <DistanceMeters>\(session.distanceM)</DistanceMeters>
                <Calories>0</Calories>
                <Intensity>Active</Intensity>
                <TriggerMethod>Manual</TriggerMethod>
              </Lap>
            </Activity>
          </Activities>
        </TrainingCenterDatabase>
        """
        return Data(xml.utf8)
    }
}
