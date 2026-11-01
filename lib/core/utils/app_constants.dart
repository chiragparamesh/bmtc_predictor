/// App-wide constants.
class AppConstants {
  static const appName = 'BMTC Delay Predictor';
  static const tagline = 'Know when your bus will really come.';

  /// Feature modules from the brief. Each one lives in `lib/features/<name>/`.
  static const modules = <AppModule>[
    AppModule('Stop Search', 'Search stops on the bundled busy routes'),
    AppModule('Schedule', 'Scheduled times from the GTFS subset'),
    AppModule('Prediction', 'Predicted delay from the Colab-exported model'),
    AppModule('Rain Mode', 'Rain mode toggle feeding the model'),
    AppModule('Arrival Report', '"Bus arrived" report button, stored locally'),
  ];
}

class AppModule {
  const AppModule(this.title, this.description);
  final String title;
  final String description;
}
