import Foundation
import Testing
@testable import HikingCore

@Suite("Geo math")
struct GeoMathTests {
    @Test("WGS84 coordinates in mainland China convert to GCJ02 for map display")
    func mainlandChinaWGS84ConvertsToGCJ02() {
        let wgs84 = GeoCoordinate(latitude: 39.908823, longitude: 116.397470)
        let gcj02 = GeoMath.wgs84ToGCJ02(wgs84)

        #expect(gcj02.latitude > 39.9100 && gcj02.latitude < 39.9105)
        #expect(gcj02.longitude > 116.4035 && gcj02.longitude < 116.4040)
    }

    @Test("WGS84 coordinates outside mainland China are unchanged")
    func coordinatesOutsideMainlandChinaStayUnchanged() {
        let wgs84 = GeoCoordinate(latitude: 37.8060, longitude: -122.4768)
        let gcj02 = GeoMath.wgs84ToGCJ02(wgs84)

        #expect(gcj02 == wgs84)
    }
}
