class Either<L, R> {
  final L? _left;
  final R? _right;
  final bool _isLeft;

  const Either._(this._left, this._right, this._isLeft);

  factory Either.left(L value) => Either._(value, null, true);
  factory Either.right(R value) => Either._(null, value, false);

  bool get isLeft => _isLeft;
  bool get isRight => !_isLeft;

  L get left => _left as L;
  R get right => _right as R;

  T fold<T>(T Function(L l) onLeft, T Function(R r) onRight) {
    return _isLeft ? onLeft(left) : onRight(right);
  }
}
