using UnityEngine;

public class CycleObjects : MonoBehaviour
{
  private GameObject[] objects;

  private int currentIndex = 0;

  private void Start()
  {
    objects = new GameObject[transform.childCount];

    for (int i = 0; i < transform.childCount; i++)
    {
      objects[i] = transform.GetChild(i).gameObject;
      objects[i].SetActive(false);
    }

    if (objects.Length > 0)
    {
      objects[currentIndex].SetActive(true);
    }
  }

  public void NextObject()
  {
    if (objects.Length == 0) return;

    objects[currentIndex].SetActive(false);
    currentIndex = (currentIndex + 1) % objects.Length;
    objects[currentIndex].SetActive(true);
  }

  public void PreviousObject()
  {
    if (objects.Length == 0) return;

    objects[currentIndex].SetActive(false);
    currentIndex = (currentIndex - 1 + objects.Length) % objects.Length;
    objects[currentIndex].SetActive(true);
  }
}