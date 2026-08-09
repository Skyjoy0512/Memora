const DEV_ONLY_ROUTES = ['preview', 'dev-fonts'] as const;

export function isDevOnlyRoute(routeName: string): boolean {
  return (DEV_ONLY_ROUTES as readonly string[]).includes(routeName);
}

export function shouldExposeRoute(routeName: string, isDev: boolean): boolean {
  return isDev || !isDevOnlyRoute(routeName);
}
