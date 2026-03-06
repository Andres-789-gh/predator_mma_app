import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/data/auth_repository.dart';
import 'attendees_state.dart';

class AttendeesCubit extends Cubit<AttendeesState> {
  final AuthRepository _authRepository;

  AttendeesCubit(this._authRepository) : super(AttendeesInitial());

  // carga perfiles de usuarios solicitados
  Future<void> loadAttendees({
    required List<String> attendeeIds,
    required List<String> waitlistIds,
  }) async {
    emit(AttendeesLoading());
    try {
      final attendees = await _authRepository.getUsersByIds(attendeeIds);
      final waitlist = await _authRepository.getUsersByIds(waitlistIds);

      // ordena nombres alfabeticamente
      attendees.sort((a, b) => a.firstName.compareTo(b.firstName));
      waitlist.sort((a, b) => a.firstName.compareTo(b.firstName));

      emit(AttendeesLoaded(attendees: attendees, waitlist: waitlist));
    } catch (e) {
      emit(AttendeesError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
