// Placeholder for a HarmonyOS Wearable ArkTS / ArkUI page.
// Move this into a real DevEco Studio Wearable project before building.

interface RouteSummary {
  routeId: string
  routeName: string
  distanceMeters: number
  syncState: string
}

const demoRoute: RouteSummary = {
  routeId: 'demo-mountain-loop',
  routeName: 'Demo Mountain Loop',
  distanceMeters: 4200,
  syncState: 'waiting'
}

@Entry
@Component
struct MainPage {
  build() {
    Column() {
      Text('Hiking WATCH Demo')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)

      Text(demoRoute.routeName)
        .fontSize(14)

      Text(`${demoRoute.distanceMeters} m`)
        .fontSize(12)

      Text(`Sync: ${demoRoute.syncState}`)
        .fontSize(12)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}

