part of 'interests_bloc.dart';

abstract class InterestsEvent extends Equatable {
  const InterestsEvent();
  @override
  List<Object?> get props => [];
}

class InterestToggled extends InterestsEvent {
  final String interest;
  const InterestToggled(this.interest);
  @override
  List<Object?> get props => [interest];
}

class InterestsSubmitted extends InterestsEvent {
  const InterestsSubmitted();
}
