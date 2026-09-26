import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { createBrowserRouter, Navigate, RouterProvider } from "react-router";
import Layout from "./components/Layout";
import Example from "./pages/Example";
import Files from "./pages/Files";
import FlowPage from "./pages/FlowPage";
import { Concepts, Config, Faq, GetStarted, Harnesses, Packs, Rules, Security, Versioning } from "./pages/Guides";
import Home from "./pages/Home";
import SkillPage from "./pages/SkillPage";
import Skills from "./pages/Skills";
import Workflow from "./pages/Workflow";
import "./styles/tokens.css";
import "./styles/app.css";

const router = createBrowserRouter(
  [
    {
      path: "/",
      element: <Layout />,
      children: [
        { index: true, element: <Home /> },
        { path: "start", element: <GetStarted /> },
        { path: "files", element: <Files /> },
        { path: "concepts", element: <Concepts /> },
        { path: "flows", element: <Navigate to="/flows/greenfield" replace /> },
        { path: "flows/:id", element: <FlowPage /> },
        { path: "workflow", element: <Workflow /> },
        { path: "workflow/:stage", element: <Workflow /> },
        { path: "skills", element: <Skills /> },
        { path: "skills/:name", element: <SkillPage /> },
        { path: "example", element: <Example /> },
        { path: "reference/config", element: <Config /> },
        { path: "reference/security", element: <Security /> },
        { path: "reference/packs", element: <Packs /> },
        { path: "reference/harnesses", element: <Harnesses /> },
        { path: "reference/repository", element: <Navigate to="/files?scope=repository" replace /> },
        { path: "reference/versioning", element: <Versioning /> },
        { path: "faq", element: <Faq /> },
        { path: "rules", element: <Rules /> },
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
