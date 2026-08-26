using UnityEngine;
using UnityEngine.InputSystem;

public class OrbitControl : MonoBehaviour
{
  [SerializeField] private Transform objectOrbit;
  [SerializeField] private Transform cameraOrbit;
  [SerializeField] private float sensitivity = 1.0f;
  [SerializeField] private float zoomSensitivity = 1.0f;
  [SerializeField] private float minZoom = .5f;
  [SerializeField] private float maxZoom = 10.0f;

  [SerializeField] private float waveAmplitude = 1.0f;
  [SerializeField] private float waveFrequency = 1.0f;

  [SerializeField] private float lerpSpeed = 5.0f;

  private Quaternion targetRotation;
  private float targetZoom;

  private void Start()
  {
    targetRotation = objectOrbit.rotation;
    targetZoom = cameraOrbit.localScale.z;
  }

  private void Update()
  {
    float waveX = Mathf.Sin(Time.time * waveFrequency) * waveAmplitude;
    float waveY = Mathf.Cos(Time.time * waveFrequency) * waveAmplitude;

    objectOrbit.rotation = Quaternion.Lerp(objectOrbit.rotation,  targetRotation * Quaternion.Euler(waveX, waveY, 0), Time.deltaTime * lerpSpeed);
    cameraOrbit.localScale = new Vector3(cameraOrbit.localScale.x, cameraOrbit.localScale.y, Mathf.Lerp(cameraOrbit.localScale.z, targetZoom, Time.deltaTime * lerpSpeed));
  }

  public void OnRotate(InputValue value)
  {
    Vector2 mouseDelta = value.Get<Vector2>() * sensitivity;

    targetRotation = Quaternion.Euler(-mouseDelta.y, 0, 0) * targetRotation;
    targetRotation = Quaternion.Euler(0, -mouseDelta.x, 0) * targetRotation;
  }

  public void OnZoom(InputValue value)
  {
    float scrollDelta = value.Get<Vector2>().y * zoomSensitivity;
    targetZoom = Mathf.Clamp(targetZoom - scrollDelta, minZoom, maxZoom);
  }
}