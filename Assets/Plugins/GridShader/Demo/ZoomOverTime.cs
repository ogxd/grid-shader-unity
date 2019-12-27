using UnityEngine;

namespace Ogxd
{
    public class ZoomOverTime : MonoBehaviour
    {
        public float speedFactor = 1f;
        public Material material;

        void Update()
        {
            material.SetFloat("_Scale", Mathf.Exp((speedFactor * Time.timeSinceLevelLoad) % 10));
        }
    }
}