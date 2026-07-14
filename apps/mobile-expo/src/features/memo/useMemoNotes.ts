import { useCallback, useEffect, useState } from 'react';
import { MemoraNative } from '../../native/MemoraNative';
import type { PhotoAttachmentDTO } from '../../native/MemoraNative.types';

export function useMemoNotes(fileId: string | undefined) {
  const [draft, setDraft] = useState('');
  const [photos, setPhotos] = useState<PhotoAttachmentDTO[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!fileId) return;
    let isMounted = true;
    setIsLoading(true);

    Promise.all([MemoraNative.getMemoDraft(fileId), MemoraNative.listPhotoAttachments(fileId)])
      .then(([nextDraft, nextPhotos]) => {
        if (!isMounted) return;
        setDraft(nextDraft);
        setPhotos(nextPhotos);
        setIsLoading(false);
      })
      .catch((loadError: unknown) => {
        if (!isMounted) return;
        setError(loadError instanceof Error ? loadError.message : 'メモを読み込めませんでした。');
        setIsLoading(false);
      });

    return () => {
      isMounted = false;
    };
  }, [fileId]);

  const saveDraft = useCallback(
    async (text: string) => {
      if (!fileId) return;
      setDraft(text);
      try {
        await MemoraNative.saveMemoDraft(fileId, text);
      } catch (saveError: unknown) {
        setError(saveError instanceof Error ? saveError.message : 'メモを保存できませんでした。');
      }
    },
    [fileId],
  );

  const addPhoto = useCallback(
    async (sourceUri: string) => {
      if (!fileId) return;
      try {
        const attachment = await MemoraNative.addPhotoAttachment(fileId, sourceUri);
        setPhotos((current) => [...current, attachment]);
      } catch (addError: unknown) {
        setError(addError instanceof Error ? addError.message : '写真を添付できませんでした。');
      }
    },
    [fileId],
  );

  const deletePhoto = useCallback(
    async (attachmentId: string) => {
      if (!fileId) return;
      try {
        const didDelete = await MemoraNative.deletePhotoAttachment(fileId, attachmentId);
        if (didDelete) {
          setPhotos((current) => current.filter((photo) => photo.id !== attachmentId));
        }
      } catch (deleteError: unknown) {
        setError(deleteError instanceof Error ? deleteError.message : '写真を削除できませんでした。');
      }
    },
    [fileId],
  );

  return { addPhoto, deletePhoto, draft, error, isLoading, photos, saveDraft };
}
