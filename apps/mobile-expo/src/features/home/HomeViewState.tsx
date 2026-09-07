// 記録一覧の表示状態（すべて / プロジェクト、選択中のプロジェクト）。
//
// Open Design v2 で一覧への常設 Ask AI コンポーザーを廃止したため、旧
// `components/HomeComposer.tsx` が抱えていた質問ドラフト・回答・モデル選択の
// 状態はここには持ち込まない。質問の状態は Ask AI 画面が単独で持つ。
import { createContext, useContext, useMemo, useState, type ReactNode } from 'react';

export type HomeViewMode = 'files' | 'projects';

type HomeViewStateValue = {
  viewMode: HomeViewMode;
  setViewMode: (value: HomeViewMode) => void;
  selectedProject: string | undefined;
  setSelectedProject: (value: string | undefined) => void;
};

const HomeViewStateContext = createContext<HomeViewStateValue | undefined>(undefined);

export function useHomeViewState(): HomeViewStateValue {
  const value = useContext(HomeViewStateContext);
  if (!value) {
    throw new Error('useHomeViewState must be used within <HomeViewStateProvider>');
  }
  return value;
}

export function HomeViewStateProvider({ children }: { children: ReactNode }) {
  const [viewMode, setViewMode] = useState<HomeViewMode>('files');
  const [selectedProject, setSelectedProject] = useState<string | undefined>();

  const value = useMemo(
    () => ({ viewMode, setViewMode, selectedProject, setSelectedProject }),
    [selectedProject, viewMode],
  );

  return <HomeViewStateContext.Provider value={value}>{children}</HomeViewStateContext.Provider>;
}
