/// O runtime dos apps do Psito: `runPsitoApp(MeuApp())` é o main inteiro de
/// um app. Os apps importam só o Flutter, pacotes externos, o `psito_sdk` e
/// este pacote.
library;

export 'src/app_context.dart' show AppServices, ProcessAppContext;
export 'src/run.dart'
    show PsitoAppHost, openedPaths, runPsitoApp, startServices;
export 'src/window.dart' show AppWindow, minWindowSize;
