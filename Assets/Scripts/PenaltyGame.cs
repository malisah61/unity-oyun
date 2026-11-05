using UnityEngine;

// Penaltı Ustası: parmağını topa koy, kaleye doğru kaydır, bırak ve şut çek.
// Kaleci sağa sola hareket eder; 5 şutta en çok golü atmaya çalış.
public class PenaltyGame : MonoBehaviour
{
    Transform ball, keeper;
    Vector2 ballStart = new Vector2(0, -5.5f);
    Vector2 velocity;
    bool flying, dragging;
    Vector2 dragStart;
    float keeperSpeed = 3f, keeperDir = 1f;
    int goals, shots, best;
    const int MaxShots = 5;
    string message = "Topu kaydır ve şut çek!";
    float messageTimer;

    const float GoalHalfWidth = 3.2f, GoalY = 6f;

    void Start()
    {
        best = PlayerPrefs.GetInt("best", 0);
        MakeRect("Kale", new Vector2(0, GoalY + 0.6f), new Vector2(GoalHalfWidth * 2 + 0.4f, 1.4f), new Color(1, 1, 1, 0.9f), -1);
        MakeRect("Ag", new Vector2(0, GoalY + 0.6f), new Vector2(GoalHalfWidth * 2, 1.2f), new Color(0.85f, 0.85f, 0.85f), 0);
        MakeRect("Ceza Cizgisi", new Vector2(0, 1f), new Vector2(12f, 0.08f), new Color(1, 1, 1, 0.6f), -2);
        keeper = MakeRect("Kaleci", new Vector2(0, GoalY - 0.2f), new Vector2(1.4f, 0.7f), new Color(1f, 0.55f, 0.1f), 2).transform;
        ball = MakeCircle("Top", ballStart, 0.45f, Color.white, 3).transform;
    }

    void Update()
    {
        MoveKeeper();
        if (messageTimer > 0) messageTimer -= Time.deltaTime;

        if (shots >= MaxShots && !flying)
        {
            if (Input.GetMouseButtonDown(0)) Restart();
            return;
        }

        Vector2 p = Camera.main.ScreenToWorldPoint(Input.mousePosition);
        if (!flying)
        {
            if (Input.GetMouseButtonDown(0) && Vector2.Distance(p, ball.position) < 1.5f) { dragging = true; dragStart = p; }
            if (Input.GetMouseButtonUp(0) && dragging)
            {
                dragging = false;
                Vector2 swipe = p - dragStart;
                if (swipe.y > 0.5f) { velocity = swipe * 4f; velocity = Vector2.ClampMagnitude(velocity, 22f); flying = true; }
            }
            return;
        }

        ball.position += (Vector3)(velocity * Time.deltaTime);
        ball.Rotate(0, 0, 720 * Time.deltaTime);

        Vector2 b = ball.position;
        if (Mathf.Abs(b.x - keeper.position.x) < 1.0f && Mathf.Abs(b.y - keeper.position.y) < 0.6f) EndShot(false, "Kaleci kurtardı!");
        else if (b.y >= GoalY) EndShot(Mathf.Abs(b.x) < GoalHalfWidth, Mathf.Abs(b.x) < GoalHalfWidth ? "GOOOL!" : "Dışarı!");
        else if (b.y > 10 || Mathf.Abs(b.x) > 8) EndShot(false, "Dışarı!");
    }

    void MoveKeeper()
    {
        float speed = keeperSpeed + goals * 0.6f;
        float x = keeper.position.x + keeperDir * speed * Time.deltaTime;
        if (Mathf.Abs(x) > GoalHalfWidth - 0.7f) { keeperDir *= -1; x = Mathf.Clamp(x, -(GoalHalfWidth - 0.7f), GoalHalfWidth - 0.7f); }
        if (Random.value < 0.01f) keeperDir *= -1;
        keeper.position = new Vector3(x, keeper.position.y, 0);
    }

    void EndShot(bool goal, string msg)
    {
        flying = false;
        shots++;
        if (goal) goals++;
        message = msg; messageTimer = 1.5f;
        ball.position = ballStart;
        if (shots >= MaxShots)
        {
            if (goals > best) { best = goals; PlayerPrefs.SetInt("best", best); }
            message = "Bitti! " + goals + "/" + MaxShots + " gol. Tekrar için dokun.";
            messageTimer = 999;
        }
    }

    void Restart() { goals = 0; shots = 0; message = "Topu kaydır ve şut çek!"; messageTimer = 2; }

    void OnGUI()
    {
        float s = Screen.width / 400f;
        var style = new GUIStyle(GUI.skin.label) { fontSize = (int)(22 * s), alignment = TextAnchor.UpperCenter, fontStyle = FontStyle.Bold };
        style.normal.textColor = Color.white;
        GUI.Label(new Rect(0, 20 * s, Screen.width, 40 * s), "Gol: " + goals + "   Şut: " + shots + "/" + MaxShots + "   Rekor: " + best, style);
        if (messageTimer > 0)
        {
            style.fontSize = (int)(30 * s);
            GUI.Label(new Rect(0, Screen.height * 0.45f, Screen.width, 60 * s), message, style);
        }
    }

    // --- Basit şekil üretimi (hazır görsel gerekmez) ---
    static Sprite square, circle;

    GameObject MakeRect(string name, Vector2 pos, Vector2 size, Color color, int order)
    {
        if (square == null) square = MakeSprite(false);
        var go = new GameObject(name);
        var sr = go.AddComponent<SpriteRenderer>();
        sr.sprite = square; sr.color = color; sr.sortingOrder = order;
        go.transform.position = pos; go.transform.localScale = size;
        return go;
    }

    GameObject MakeCircle(string name, Vector2 pos, float radius, Color color, int order)
    {
        if (circle == null) circle = MakeSprite(true);
        var go = MakeRect(name, pos, Vector2.one * radius * 2, color, order);
        go.GetComponent<SpriteRenderer>().sprite = circle;
        return go;
    }

    static Sprite MakeSprite(bool round)
    {
        const int n = 64;
        var tex = new Texture2D(n, n);
        for (int y = 0; y < n; y++)
            for (int x = 0; x < n; x++)
            {
                float dx = x - n / 2f + 0.5f, dy = y - n / 2f + 0.5f;
                bool inside = !round || dx * dx + dy * dy <= (n / 2f) * (n / 2f);
                tex.SetPixel(x, y, inside ? Color.white : Color.clear);
            }
        tex.Apply();
        return Sprite.Create(tex, new Rect(0, 0, n, n), new Vector2(0.5f, 0.5f), n);
    }
}
