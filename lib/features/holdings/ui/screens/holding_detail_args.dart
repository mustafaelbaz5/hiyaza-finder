import '../../domain/entities/parcel.dart';

/// Navigation arguments for `Routes.holdingDetail`. Kept as a class (mirrors
/// `AddRecordArgs`) — rather than passing `List<Parcel>` directly — so
/// `DetailScreen.backToHome` can travel through `Navigator.pushNamed`.
///
/// Lives in its own file (not inside `detail_screen.dart`) so
/// `ParcelDetailCard` — which needs it to navigate from a الحدود tap — can
/// import it without also importing `DetailScreen` itself and creating a
/// widget/screen import cycle.
class HoldingDetailArgs {
  const HoldingDetailArgs({required this.parcels, this.backToHome = false});

  final List<Parcel> parcels;
  final bool backToHome;
}
