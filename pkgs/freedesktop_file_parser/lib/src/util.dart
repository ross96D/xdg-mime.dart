
sealed class Result<Ok, Err> {
  const Result();

  const factory Result.ok(Ok ok) = ResultOk;
  const factory Result.error(Err ok) = ResultErr;

  Ok unwrap() {
    if (this is ResultOk<Ok, Err>) {
      return (this as ResultOk<Ok, Err>).ok;
    }
    throw ArgumentError("Result is not a ResultOk");
  }
}

class ResultOk<Ok, Err> extends Result<Ok, Err> {
  final Ok ok;

  const ResultOk(this.ok);
}

class ResultErr<Ok, Err> extends Result<Ok, Err> {
  final Err error;

  const ResultErr(this.error);
}
