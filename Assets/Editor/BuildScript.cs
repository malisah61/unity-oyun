using System;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;

// Bulutta (GitHub Actions) çağrılan derleme betiği.
// Sahneyi kodla oluşturur, böylece Unity editörünü hiç açmadan APK çıkar.
public static class BuildScript
{
    const string ScenePath = "Assets/Scenes/Main.unity";

    [MenuItem("Oyun/Android APK Derle")]
    public static void BuildAndroid()
    {
        EnsureScene();

        PlayerSettings.companyName = "malisah61";
        PlayerSettings.productName = "Penalti Ustasi";
        PlayerSettings.SetApplicationIdentifier(BuildTargetGroup.Android, "com.malisah61.penalti");
        PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;
        PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel24;
        EditorUserBuildSettings.buildAppBundle = false;

        string outPath = GetArg("-customBuildPath") ?? "build/Android/PenaltiUstasi.apk";
        if (!outPath.EndsWith(".apk")) outPath = Path.Combine(outPath, "PenaltiUstasi.apk");
        Directory.CreateDirectory(Path.GetDirectoryName(outPath));

        var report = BuildPipeline.BuildPlayer(new BuildPlayerOptions
        {
            scenes = new[] { ScenePath },
            locationPathName = outPath,
            target = BuildTarget.Android,
            options = BuildOptions.None
        });

        Debug.Log("Derleme sonucu: " + report.summary.result + " -> " + outPath);
        if (Application.isBatchMode)
            EditorApplication.Exit(report.summary.result == UnityEditor.Build.Reporting.BuildResult.Succeeded ? 0 : 1);
    }

    static void EnsureScene()
    {
        Directory.CreateDirectory("Assets/Scenes");
        var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
        var cam = new GameObject("Main Camera");
        cam.tag = "MainCamera";
        var c = cam.AddComponent<Camera>();
        c.orthographic = true;
        c.orthographicSize = 8;
        c.clearFlags = CameraClearFlags.SolidColor;
        c.backgroundColor = new Color(0.16f, 0.55f, 0.25f);
        cam.transform.position = new Vector3(0, 0, -10);
        new GameObject("Game").AddComponent<PenaltyGame>();
        EditorSceneManager.SaveScene(scene, ScenePath);
        EditorBuildSettings.scenes = new[] { new EditorBuildSettingsScene(ScenePath, true) };
        AssetDatabase.SaveAssets();
    }

    static string GetArg(string name)
    {
        var args = Environment.GetCommandLineArgs();
        for (int i = 0; i < args.Length - 1; i++)
            if (args[i] == name) return args[i + 1];
        return null;
    }
}
