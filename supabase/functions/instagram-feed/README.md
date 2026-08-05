# Instagram-Feed

Die Edge Function liest die neuesten öffentlichen Beiträge des Vereinskontos.
Zugriffstoken und numerische Instagram-ID bleiben ausschließlich serverseitig.

Benötigte Secrets:

- `INSTAGRAM_ACCESS_TOKEN`: initialer langlebiger Instagram-Zugriffstoken
- `INSTAGRAM_USER_ID`: numerische Instagram-ID aus der Meta-Einrichtung

Nach der Migration `20260805_013_instagram_token_refresh.sql` erneuert die
Function den langlebigen Token spätestens alle sechs Tage und speichert die
neue Version in einer ausschließlich für den Service-Role zugänglichen Tabelle.
Ein wöchentlicher Supabase-Cron-Aufruf stellt die Erneuerung auch dann sicher,
wenn die App längere Zeit nicht geöffnet wird.

Der Secret-Token bleibt als Notfall-Fallback erhalten. Er darf niemals in die
Flutter-App, in Logs oder in Git eingecheckt werden.
