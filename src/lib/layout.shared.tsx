import type { BaseLayoutProps } from "fumadocs-ui/layouts/shared";
import { APP_NAME } from "@/constants";

// fill this with your actual GitHub info, for example:
export const gitConfig = {
  user: "hobenakicoffee",
  repo: "playground",
  branch: "main",
};

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: APP_NAME,
    },
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
  };
}
