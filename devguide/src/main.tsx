import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { createBrowserRouter, Navigate, RouterProvider } from "react-router";
import Layout from "./components/Layout";
import { Adopt, Scaffold } from "./pages/Scaffold";
import { Agents } from "./pages/Agents";
import { Architecture } from "./pages/Architecture";
import { Autopilot } from "./pages/Autopilot";
import { Change, Release } from "./pages/Change";
import { Gates } from "./pages/Gates";
import { Guard } from "./pages/Guard";
import { Harnesses, Install, Trackers } from "./pages/Platform";
import Home from "./pages/Home";
import { Glossary, Replays } from "./pages/Reference";
import { ScriptPage, Scripts } from "./pages/Scripts";
import { Session } from "./pages/Session";
import { SkillPage, Skills, SkillsWork } from "./pages/Skills";
import { Start } from "./pages/Start";
import "./styles/tokens.css";
import "./styles/app.css";

const router = createBrowserRouter(
  [
    {
      path: "/",
      element: <Layout />,
      children: [
        { index: true, element: <Home /> },
        { path: "start", element: <Start /> },
        { path: "architecture", element: <Architecture /> },
        { path: "session", element: <Session /> },
        { path: "guard", element: <Guard /> },
        { path: "skills-work", element: <SkillsWork /> },
        { path: "agents", element: <Agents /> },
        { path: "scaffold", element: <Scaffold /> },
        { path: "adopt", element: <Adopt /> },
        { path: "autopilot", element: <Autopilot /> },
        { path: "trackers", element: <Trackers /> },
        { path: "harnesses", element: <Harnesses /> },
        { path: "install", element: <Install /> },
        { path: "gates", element: <Gates /> },
        { path: "change", element: <Change /> },
        { path: "release", element: <Release /> },
        { path: "scripts", element: <Scripts /> },
        { path: "scripts/:name", element: <ScriptPage /> },
        { path: "skills", element: <Skills /> },
        { path: "skills/:name", element: <SkillPage /> },
        { path: "replays", element: <Replays /> },
        { path: "glossary", element: <Glossary /> },
        { path: "*", element: <Navigate to="/" replace /> },
      ],
    },
  ],
  { basename: import.meta.env.BASE_URL.replace(/\/$/, "") || "/" },
);

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <RouterProvider router={router} />
  </StrictMode>,
);
