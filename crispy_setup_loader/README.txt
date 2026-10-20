Crispy Setup Loader v0.2.5 (reliability fix)

Install: assettocorsa/apps/lua/crispy_setup_loader/

The app is visible in the setup menu (SETUP,AUTO_RESIZE).

Auto-load runs once per game join, targeting either a remembered setup per car or generic/last.ini.
With "Try loading immediately" enabled, it attempts a pre-menu load 1.5 seconds after joining.
CSP documents ac.loadSetup() as working only in the setup menu, so this experimental attempt can fail.

Unlike v0.2.4, if the pre-menu attempt fails the app waits for the FIRST setup-screen opening,
then tries up to three times over a short initial window. It does not retry after that window,
so later setup changes are not overwritten. A manual setup load/save cancels auto-load.

Manual force-load buttons remain available on the setup screen.
The setup must be editable (not locked by the server).

Important: This does NOT guarantee the setup is already applied before you click Drive.
CSP's documented API cannot guarantee setup loading outside the setup menu.
